# Create a secret to store the Jenkins API token
resource "random_id" "secret_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "jenkins_api_token" {
  name        = "jenkins-api-token-${var.environment}-${random_id.secret_suffix.hex}"
  description = "Jenkins API token for security scan automation"
  tags        = var.tags
}

# Note: The actual secret value should be set manually or through a separate process
# as it's not recommended to store sensitive values in version control 