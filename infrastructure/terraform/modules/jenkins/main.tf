# Security group for Jenkins master
resource "aws_security_group" "jenkins_master_sg" {
  name        = "jenkins-master-sg-${var.environment}"
  description = "Security group for Jenkins master"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_outbound_cidr_blocks
  }

  tags = merge(
    {
      Name        = "jenkins-master-sg-${var.environment}"
      Environment = var.environment
      Terraform   = "true"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Add data source for AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Add data source for current region
data "aws_region" "current" {}

# Create a secret for Jenkins admin password
resource "aws_secretsmanager_secret" "jenkins_admin_password" {
  name        = "jenkins-admin-password-${var.environment}"
  description = "Initial Jenkins administrator password for ${var.environment} environment"
}

# Jenkins master instance
resource "aws_instance" "jenkins_master" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.jenkins_master_instance_type
  subnet_id     = var.subnet_id
  
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins_master.name

  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]
  key_name              = var.key_name

  root_block_device {
    volume_size = 30
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting Jenkins installation..."
              
              # Install SSM agent
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              
              # Wait for any existing yum processes to finish
              while pgrep -f yum > /dev/null; do
                echo "Waiting for other yum processes to complete..."
                sleep 10
              done
              
              # Update system
              sudo yum update -y
              
              # Install Java 17
              sudo yum install -y java-17-amazon-corretto
              
              # Install required packages
              sudo yum install -y unzip wget git

              # Install CodeQL CLI
              CODEQL_VERSION="2.20.4"
              wget https://github.com/github/codeql-cli-binaries/releases/download/v$${CODEQL_VERSION}/codeql-linux64.zip
              unzip codeql-linux64.zip
              sudo mv codeql /usr/local/
              sudo ln -s /usr/local/codeql/codeql /usr/local/bin/codeql
              
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
              
              # Store admin password in Secrets Manager
              aws secretsmanager put-secret-value \
                --secret-id ${aws_secretsmanager_secret.jenkins_admin_password.name} \
                --secret-string "$ADMIN_PASSWORD" \
                --region ${data.aws_region.current.name}
              
              echo "Jenkins setup completed"
              EOF

  metadata_options {
    http_tokens = "required"  # Use IMDSv2
  }

  tags = merge(
    {
      Name        = "jenkins-master-${var.environment}"
      Environment = var.environment
      Terraform   = "true"
    },
    var.tags
  )
}

# Add a more explicit wait condition
resource "time_sleep" "wait_for_jenkins" {
  depends_on = [aws_instance.jenkins_master]
  create_duration = "180s"
}

# Add an SSM command to verify Jenkins initialization
resource "aws_ssm_association" "verify_jenkins" {
  depends_on = [time_sleep.wait_for_jenkins]
  name = "AWS-RunShellScript"
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.jenkins_master.id]
  }

  parameters = {
    commands = <<-EOF
      #!/bin/bash
      for i in {1..30}; do
        if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
          ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
          aws secretsmanager put-secret-value --secret-id ${aws_secretsmanager_secret.jenkins_admin_password.name} --secret-string "$ADMIN_PASSWORD" --region ${data.aws_region.current.name}
          exit 0
        fi
        echo "Waiting for Jenkins to initialize... ($i/30)"
        sleep 10
      done
      exit 1
    EOF
  }
}