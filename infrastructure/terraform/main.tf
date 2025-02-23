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
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

# Finally create CodeQL
module "security_scanner" {
  source = "./modules/security_scanner"

  vpc_id                    = module.vpc.vpc_id
  subnet_id                 = module.vpc.public_subnets[1]
  environment              = var.environment
  key_name                 = aws_key_pair.jenkins_key.key_name
  allowed_ssh_cidr_blocks  = [
    format("%s/32", module.jenkins.jenkins_master_private_ip),
    "73.202.208.108/32"  # Your IP address
  ]
  allowed_http_cidr_blocks = [format("%s/32", module.jenkins.jenkins_master_private_ip)]
  allowed_https_cidr_blocks = [format("%s/32", module.jenkins.jenkins_master_private_ip)]
  volume_size = 64  # Increase from default 32GB to 64GB
  db_credentials_secret_arn = module.rds.db_credentials_secret_arn
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
  
  tags = {
    Environment = var.environment
    Project     = "security-scanning"
  }
}