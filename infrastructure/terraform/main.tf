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
              
              # Wait for Jenkins to start up properly
              echo "Waiting for Jenkins to start..."
              timeout 300 bash -c '
                until curl -s -L http://localhost:8080 > /dev/null; do
                  echo "Waiting for Jenkins to start... retrying in 5s"
                  sleep 5
                done'
              
              # Wait additional time for Jenkins to fully initialize
              sleep 30
              
              # Get the initial admin password
              ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
              echo "Admin password: $ADMIN_PASSWORD"
              
              # Download Jenkins CLI with retry
              echo "Downloading Jenkins CLI..."
              for i in {1..12}; do
                if curl -s -L http://localhost:8080/jnlpJars/jenkins-cli.jar -o jenkins-cli.jar; then
                  break
                fi
                echo "Failed to download jenkins-cli.jar, attempt $i/12. Retrying in 10s..."
                sleep 10
              done
              
              if [ ! -f jenkins-cli.jar ]; then
                echo "Failed to download jenkins-cli.jar after all attempts"
                exit 1
              fi
              
              # Install required plugins with retry logic
              echo "Installing Jenkins plugins..."
              PLUGINS="dependency-check-jenkins-plugin codeql workflow-aggregator git pipeline-utility-steps configuration-as-code"
              
              for plugin in $PLUGINS; do
                echo "Installing plugin: $plugin"
                for i in {1..3}; do
                  if java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD install-plugin "$plugin" -deploy; then
                    echo "Successfully installed $plugin"
                    break
                  fi
                  echo "Failed to install $plugin, attempt $i/3. Retrying in 10s..."
                  sleep 10
                done
              done
              
              # Restart Jenkins
              echo "Restarting Jenkins..."
              java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD safe-restart || true
              
              # Wait for Jenkins to come back up
              echo "Waiting for Jenkins to restart..."
              sleep 30
              timeout 300 bash -c '
                until curl -s -L http://localhost:8080 > /dev/null; do
                  echo "Waiting for Jenkins to restart... retrying in 5s"
                  sleep 5
                done'
              
              echo "Jenkins installation and plugin setup completed"
              EOF

  tags = {
    Name        = "jenkins-master"
    Environment = var.environment
  }
}