#!/bin/bash
set -e

# Log setup progress
exec > >(tee /var/log/security-scanner-setup.log) 2>&1
echo "Starting security scanner setup at $(date)"

# Install required packages
echo "Installing required packages..."
yum update -y
yum install -y git docker wget unzip java-11-amazon-corretto-headless python3 python3-pip

# Start and enable Docker
echo "Configuring Docker..."
systemctl start docker
systemctl enable docker

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install boto3 requests

# Install CodeQL
echo "Installing CodeQL..."
CODEQL_VERSION="2.20.4"
cd /opt
wget https://github.com/github/codeql-cli-binaries/releases/download/v$CODEQL_VERSION/codeql-linux64.zip
unzip codeql-linux64.zip
rm codeql-linux64.zip
mv codeql /usr/local/
ln -s /usr/local/codeql/codeql /usr/local/bin/codeql

# Install OWASP Dependency Check
echo "Installing OWASP Dependency Check..."
DC_VERSION="12.0.2"
DC_DIR="/usr/share/dependency-check"
mkdir -p $DC_DIR
cd $DC_DIR
wget "https://github.com/jeremylong/DependencyCheck/releases/download/v$DC_VERSION/dependency-check-$DC_VERSION-release.zip"
unzip "dependency-check-$DC_VERSION-release.zip"
rm "dependency-check-$DC_VERSION-release.zip"
ln -s $DC_DIR/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check

# Create jenkins user and group
echo "Setting up jenkins user and directories..."
groupadd jenkins
useradd -g jenkins jenkins

# Set up directories for Jenkins agent
mkdir -p /home/jenkins
chown -R jenkins:jenkins /home/jenkins

# Set up directories for security scanner
mkdir -p /var/lib/security_scanner/results
mkdir -p /var/log/security_scanner
mkdir -p /opt/security_scanner
chown -R jenkins:jenkins /var/lib/security_scanner
chown -R jenkins:jenkins /var/log/security_scanner
chown -R jenkins:jenkins /opt/security_scanner

# Give jenkins user access to necessary directories
usermod -aG docker jenkins
mkdir -p /var/lib/codeql
chown -R jenkins:jenkins /var/lib/codeql
mkdir -p /var/lib/dependency-check
chown -R jenkins:jenkins /var/lib/dependency-check

# Allow jenkins user to execute required commands
echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/codeql" | tee -a /etc/sudoers.d/jenkins
echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/dependency-check" | tee -a /etc/sudoers.d/jenkins

# Set up SSH access for jenkins user
mkdir -p /home/jenkins/.ssh
touch /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/authorized_keys

# Set up systemd service for worker
echo "Setting up systemd service..."
cat > /etc/systemd/system/security-scanner-worker.service << SERVICEFILE
[Unit]
Description=Security Scanner Worker Service
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
WorkingDirectory=/var/lib/security_scanner
ExecStart=/usr/bin/python3 /opt/security_scanner/scan_worker.py
Restart=always
RestartSec=10
Environment=SCAN_QUEUE_URL=${scan_queue_url}
Environment=GITHUB_TOKEN_SECRET_ARN=${github_token_secret_arn}
Environment=DB_CREDENTIALS_SECRET_ARN=${db_credentials_secret_arn}

[Install]
WantedBy=multi-user.target
SERVICEFILE

# Enable and start the worker service
echo "Enabling and starting worker service..."
systemctl daemon-reload
systemctl enable security-scanner-worker
systemctl start security-scanner-worker

echo "Security scanner setup completed at $(date)" 