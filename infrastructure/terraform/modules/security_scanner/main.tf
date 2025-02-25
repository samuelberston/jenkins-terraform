resource "aws_security_group" "security_scanner" {
  name        = "security-scanner-${var.environment}"
  description = "Security group for Security Scanner instance (CodeQL & Dependency Check)"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["73.202.208.108/32"]  # Your IP address
  }

  # Jenkins port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr_blocks
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr_blocks
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "security-scanner-sg-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Move the data source outside of the launch template resource
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Create template files with variable substitution
resource "local_file" "worker_service" {
  content = templatefile("${path.module}/files/security-scanner-worker.service", {
    scan_queue_url = var.scan_queue_url
    github_token_secret_arn = var.github_token_secret_arn
    db_credentials_secret_arn = var.db_credentials_secret_arn
  })
  filename = "${path.module}/files/rendered/security-scanner-worker.service"
}

resource "aws_instance" "security_scanner" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids     = [aws_security_group.security_scanner.id]
  associate_public_ip_address = true
  key_name                   = var.key_name
  iam_instance_profile       = aws_iam_instance_profile.security_scanner.name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  # Use a minimal user_data script that downloads the setup script from S3
  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
              
              # Install AWS CLI if not already installed
              if ! command -v aws &> /dev/null; then
                yum install -y unzip
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                ./aws/install
              fi
              
              # Create directories
              mkdir -p /opt/security_scanner
              mkdir -p /var/log/security_scanner
              
              # Download setup script from S3
              aws s3 cp s3://${var.setup_bucket}/security-scanner-setup.sh /opt/security_scanner/
              aws s3 cp s3://${var.setup_bucket}/scan_worker.py /opt/security_scanner/
              
              # Make scripts executable
              chmod +x /opt/security_scanner/security-scanner-setup.sh
              chmod +x /opt/security_scanner/scan_worker.py
              
              # Export environment variables
              export SCAN_QUEUE_URL="${var.scan_queue_url}"
              export GITHUB_TOKEN_SECRET_ARN="${var.github_token_secret_arn}"
              export DB_CREDENTIALS_SECRET_ARN="${var.db_credentials_secret_arn}"
              
              # Run setup script
              /opt/security_scanner/security-scanner-setup.sh > /var/log/security_scanner/setup.log 2>&1
              EOF
  )

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(
    {
      Name        = "security-scanner-${var.environment}"
      Environment = var.environment
      Managed     = "terraform"
    },
    var.tags
  )
}

data "aws_caller_identity" "current" {}