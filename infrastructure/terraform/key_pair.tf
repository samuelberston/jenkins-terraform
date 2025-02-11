# Generate random suffix for the secret name
resource "random_id" "secret_suffix" {
  byte_length = 4
}

resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key-${var.environment}-${random_id.secret_suffix.hex}"
  public_key = tls_private_key.jenkins_key.public_key_openssh

  lifecycle {
    create_before_destroy = true
  }
}

# Store the private key in AWS Secrets Manager with a unique name
resource "aws_secretsmanager_secret" "jenkins_key" {
  name                           = "jenkins-ssh-key-${var.environment}-${random_id.secret_suffix.hex}"
  force_overwrite_replica_secret = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "jenkins_key" {
  secret_id     = aws_secretsmanager_secret.jenkins_key.id
  secret_string = tls_private_key.jenkins_key.private_key_pem
} 