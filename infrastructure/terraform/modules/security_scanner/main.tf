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

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y git docker wget unzip java-11-amazon-corretto-headless

              # Install Node.js and npm
              curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
              export NVM_DIR="$HOME/.nvm"
              [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
              [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
              nvm install --lts
              nvm use --lts

              # Make Node.js available system-wide
              ln -s "$NVM_DIR/versions/node/$(nvm version)/bin/node" /usr/local/bin/node
              ln -s "$NVM_DIR/versions/node/$(nvm version)/bin/npm" /usr/local/bin/npm

              # Start and enable Docker
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

              # Create a script to initialize environment variables
              cat > /etc/profile.d/codeql-env.sh << 'ENVSCRIPT'
              export PATH="/usr/local/bin:$PATH"
              export NODE_PATH="/usr/local/lib/node_modules"
              ENVSCRIPT

              # Make the script executable
              chmod +x /etc/profile.d/codeql-env.sh

              # Verify installations
              source /etc/profile.d/codeql-env.sh
              codeql version
              node --version
              npm --version

              # Install OWASP Dependency Check
              DC_VERSION="12.0.2"
              DC_DIR="/usr/share/dependency-check"
              sudo mkdir -p $DC_DIR
              cd $DC_DIR
              wget "https://github.com/jeremylong/DependencyCheck/releases/download/v$${DC_VERSION}/dependency-check-$${DC_VERSION}-release.zip"
              unzip "dependency-check-$${DC_VERSION}-release.zip"
              rm "dependency-check-$${DC_VERSION}-release.zip"
              sudo ln -s $DC_DIR/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check

              # Initialize NVD database (this may take a while but saves time later)
              dependency-check --updateonly

              # Create a daily cron job to update the NVD database
              echo "0 0 * * * dependency-check --updateonly" | sudo tee -a /var/spool/cron/root

              # Create jenkins user and group
              sudo groupadd jenkins
              sudo useradd -g jenkins jenkins
              
              # Set up directories for Jenkins agent
              sudo mkdir -p /home/jenkins
              sudo chown -R jenkins:jenkins /home/jenkins
              
              # Give jenkins user access to necessary directories
              sudo usermod -aG docker jenkins
              sudo mkdir -p /var/lib/codeql
              sudo chown -R jenkins:jenkins /var/lib/codeql
              sudo mkdir -p /var/lib/dependency-check
              sudo chown -R jenkins:jenkins /var/lib/dependency-check
              
              # Allow jenkins user to execute required commands
              echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/codeql" | sudo tee -a /etc/sudoers.d/jenkins
              echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/dependency-check" | sudo tee -a /etc/sudoers.d/jenkins
              
              # Set up SSH access for jenkins user
              sudo mkdir -p /home/jenkins/.ssh
              sudo touch /home/jenkins/.ssh/authorized_keys
              sudo chown -R jenkins:jenkins /home/jenkins/.ssh
              sudo chmod 700 /home/jenkins/.ssh
              sudo chmod 600 /home/jenkins/.ssh/authorized_keys
              
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