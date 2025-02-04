provider "aws" {
  region = var.aws_region
}

provider "tls" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "jenkins-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = var.environment
    Project     = "jenkins"
  }
}

# Security group for Jenkins master
resource "aws_security_group" "jenkins_master_sg" {
  name        = "jenkins-master-sg"
  description = "Security group for Jenkins master"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr_blocks]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Jenkins master instance
resource "aws_instance" "jenkins_master" {
  ami           = var.jenkins_master_ami
  instance_type = var.jenkins_master_instance_type
  subnet_id     = module.vpc.public_subnets[0]
  
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]
  key_name              = aws_key_pair.jenkins_key.key_name

  root_block_device {
    volume_size = 30
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              sudo yum install jenkins java-11-openjdk-devel -y
              sudo systemctl start jenkins
              sudo systemctl enable jenkins
              EOF

  tags = {
    Name        = "jenkins-master"
    Environment = var.environment
  }
} 