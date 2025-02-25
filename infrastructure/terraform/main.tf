provider "aws" {
  region = var.aws_region
}

provider "tls" {}

provider "random" {}

# First create the shared VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "shared-vpc-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
  }
}

# Then create Jenkins
module "jenkins" {
  source = "./modules/jenkins"

  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.public_subnets[0]
  environment         = var.environment
  key_name            = aws_key_pair.jenkins_key.key_name
  admin_cidr_blocks   = var.admin_cidr_blocks
  # allowed_outbound_cidr_blocks = ["0.0.0.0/0"]  # Optional: uncomment to override default
  
  jenkins_ssh_key_secret_name = aws_secretsmanager_secret.jenkins_key.name
  jenkins_ssh_key_secret_arn  = aws_secretsmanager_secret.jenkins_key.arn
  db_credentials_secret_arn   = module.rds.db_credentials_secret_arn
  github_token_secret_arn     = aws_secretsmanager_secret.github_token.arn
  scan_queue_url              = aws_sqs_queue.scan_queue.url
  scan_queue_arn              = aws_sqs_queue.scan_queue.arn
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

# Create SSH key pair for security scanner
resource "tls_private_key" "security_scanner_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store the private key in Secrets Manager
resource "aws_secretsmanager_secret" "security_scanner_key" {
  name        = "security-scanner-ssh-key-${var.environment}"
  description = "SSH private key for security scanner instance"
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "security_scanner_key" {
  secret_id = aws_secretsmanager_secret.security_scanner_key.id
  secret_string = jsonencode({
    private_key = tls_private_key.security_scanner_key.private_key_pem
    public_key  = tls_private_key.security_scanner_key.public_key_pem
  })
}

# Create AWS key pair
resource "aws_key_pair" "security_scanner_key" {
  key_name   = "security-scanner-key-${var.environment}"
  public_key = tls_private_key.security_scanner_key.public_key_openssh
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

# Create S3 bucket for security scanner setup scripts
resource "aws_s3_bucket" "security_scanner_setup" {
  bucket = "security-scanner-setup-${var.environment}-${random_id.suffix.hex}"

  tags = {
    Name        = "security-scanner-setup-${var.environment}"
    Environment = var.environment
    Managed     = "terraform"
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "security_scanner_setup" {
  bucket = aws_s3_bucket.security_scanner_setup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Generate a random ID for resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Finally create CodeQL
module "security_scanner" {
  source = "./modules/security_scanner"

  vpc_id                    = module.vpc.vpc_id
  subnet_id                 = module.vpc.public_subnets[1]
  environment              = var.environment
  key_name                 = aws_key_pair.security_scanner_key.key_name
  allowed_ssh_cidr_blocks  = [
    format("%s/32", module.jenkins.jenkins_master_private_ip),
    "73.202.208.108/32"  # Your IP address
  ]
  allowed_http_cidr_blocks = [format("%s/32", module.jenkins.jenkins_master_private_ip)]
  allowed_https_cidr_blocks = [format("%s/32", module.jenkins.jenkins_master_private_ip)]
  volume_size = 64  # Increase from default 32GB to 64GB
  db_credentials_secret_arn = module.rds.db_credentials_secret_arn
  scan_queue_url = aws_sqs_queue.scan_queue.url
  scan_queue_arn = aws_sqs_queue.scan_queue.arn
  github_token_secret_arn = aws_secretsmanager_secret.github_token.arn
  setup_bucket = aws_s3_bucket.security_scanner_setup.bucket
}

# Create RDS instance
module "rds" {
  source = "./modules/rds"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnets

  allowed_security_group_ids = [
    module.jenkins.jenkins_master_security_group_id,
    module.security_scanner.security_group_id
  ]

  # Optional: override defaults
  instance_class       = "db.t3.medium"
  allocated_storage    = 20
  database_name        = "appdb"
  master_username      = "dbadmin"

  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

# Add API module
module "security_scan_api" {
  source = "./modules/api"
  
  environment = var.environment
  jenkins_url = module.jenkins.jenkins_url
  scan_queue_url = aws_sqs_queue.scan_queue.url
  scan_queue_arn = aws_sqs_queue.scan_queue.arn
  jenkins_api_token_secret_arn = aws_secretsmanager_secret.jenkins_api_token.arn
  
  tags = {
    Environment = var.environment
    Project     = "security-scanning"
  }
}

# Create Jenkins API token secret
resource "aws_secretsmanager_secret" "jenkins_api_token" {
  name        = "jenkins-api-token-${var.environment}"
  description = "Jenkins API token for security scan automation"
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

# Add SQS queue for scan jobs
resource "aws_sqs_queue" "scan_queue" {
  name                      = "security-scan-queue-${var.environment}"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 86400  # 1 day
  receive_wait_time_seconds = 10
  
  tags = {
    Environment = var.environment
    Project     = "security-scanning"
    Terraform   = "true"
  }
}

# Grant permissions to the API and security scanner to use the queue
resource "aws_iam_policy" "sqs_access" {
  name        = "security-scan-sqs-access-${var.environment}"
  description = "Allow access to the security scan SQS queue"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ],
        Effect   = "Allow",
        Resource = aws_sqs_queue.scan_queue.arn
      }
    ]
  })
}

# Create GitHub access token secret
resource "aws_secretsmanager_secret" "github_token" {
  name        = "github-access-token-${var.environment}"
  description = "GitHub access token for cloning repositories"
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}