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
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting Jenkins installation..."
              
              # Wait for any existing yum processes to finish
              while pgrep -f yum > /dev/null; do
                echo "Waiting for other yum processes to complete..."
                sleep 10
              done
              
              # Update system
              sudo yum update -y
              
              # Install Java 17
              sudo yum install -y java-17-amazon-corretto
              
              # Add Jenkins repo
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              
              # Install Jenkins
              sudo yum install -y jenkins --nogpgcheck
              
              # Fix Jenkins service file
              cat <<-SYSTEMD | sudo tee /etc/systemd/system/jenkins.service
              [Unit]
              Description=Jenkins Continuous Integration Server
              Requires=network.target
              After=network.target
              
              [Service]
              Type=simple
              Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto"
              Environment="JENKINS_HOME=/var/lib/jenkins"
              Environment="JENKINS_PORT=8080"
              User=jenkins
              ExecStart=/usr/bin/java -Djava.awt.headless=true -jar /usr/share/java/jenkins.war --webroot=/var/cache/jenkins/war --httpPort=8080
              Restart=on-failure
              RestartSec=10
              
              [Install]
              WantedBy=multi-user.target
              SYSTEMD
              
              # Set up Jenkins directories
              sudo mkdir -p /var/lib/jenkins
              sudo mkdir -p /var/cache/jenkins/war
              sudo chown -R jenkins:jenkins /var/lib/jenkins
              sudo chown -R jenkins:jenkins /var/cache/jenkins
              sudo chmod -R 755 /var/lib/jenkins
              sudo chmod -R 755 /var/cache/jenkins
              
              # Reload systemd and start Jenkins
              sudo systemctl daemon-reload
              sudo systemctl enable jenkins
              sudo systemctl start jenkins
              
              # Print status for debugging
              echo "Jenkins installation completed"
              sudo systemctl status jenkins
              EOF

  tags = {
    Name        = "jenkins-master"
    Environment = var.environment
  }
} 