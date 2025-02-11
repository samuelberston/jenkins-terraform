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

# Add data source for AMI like CodeQL module
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Jenkins master instance
resource "aws_instance" "jenkins_master" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.jenkins_master_instance_type
  subnet_id     = var.subnet_id
  
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]
  key_name              = var.key_name

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
              PLUGINS="dependency-check-jenkins-plugin codeql workflow-aggregator git pipeline-utility-steps configuration-as-code ssh-agent credentials-binding"
              
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
              
              # Wait for Jenkins to restart and come back up
              echo "Waiting for Jenkins to restart..."
              sleep 30
              timeout 300 bash -c '
                until curl -s -L http://localhost:8080 > /dev/null; do
                  echo "Waiting for Jenkins to restart... retrying in 5s"
                  sleep 5
                done'

              # Get the SSH private key from AWS Secrets Manager
              echo "Retrieving SSH key from Secrets Manager..."
              REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
              SSH_KEY=$(aws secretsmanager get-secret-value \
                --region $REGION \
                --secret-id ${var.jenkins_ssh_key_secret_name} \
                --query SecretString \
                --output text)

              # Create Jenkins credentials using the CLI
              echo "Adding SSH credentials to Jenkins..."
              cat <<-CREDS > /tmp/ssh-cred.xml
              <com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.19">
                <scope>GLOBAL</scope>
                <id>codeql-ssh-key</id>
                <description>SSH key for CodeQL instance</description>
                <username>ec2-user</username>
                <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
                  <privateKey>$${SSH_KEY}</privateKey>
                </privateKeySource>
              </com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
              CREDS

              # Add the credentials using Jenkins CLI
              java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD \
                create-credentials-by-xml system::system::jenkins _ < /tmp/ssh-cred.xml

              # Clean up
              rm /tmp/ssh-cred.xml

              echo "Jenkins setup completed"
              EOF

  tags = merge(
    {
      Name        = "jenkins-master-${var.environment}"
      Environment = var.environment
      Terraform   = "true"
    },
    var.tags
  )
}