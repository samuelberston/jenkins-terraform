resource "aws_security_group" "codeql" {
  name        = "codeql-${var.environment}"
  description = "Security group for CodeQL instance"
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
      Name        = "codeql-sg-${var.environment}"
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

resource "aws_instance" "codeql" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids     = [aws_security_group.codeql.id]
  associate_public_ip_address = true
  key_name                   = var.key_name
  iam_instance_profile       = aws_iam_instance_profile.codeql.name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y git docker wget unzip
              systemctl start docker
              systemctl enable docker

              # Install CodeQL
              CODEQL_VERSION="2.20.4"
              cd /opt
              wget https://github.com/github/codeql-cli-binaries/releases/download/v$${CODEQL_VERSION}/codeql-linux64.zip
              unzip codeql-linux64.zip
              rm codeql-linux64.zip
              mv codeql /usr/local/
              ln -s /usr/local/codeql/codeql /usr/local/bin/codeql

              # Verify installation
              codeql version
              EOF
  )

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(
    {
      Name        = "codeql-${var.environment}"
      Environment = var.environment
      Managed     = "terraform"
    },
    var.tags
  )
}

data "aws_caller_identity" "current" {}