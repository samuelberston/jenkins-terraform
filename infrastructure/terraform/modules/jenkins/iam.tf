resource "aws_iam_role" "jenkins_master" {
  name = "jenkins-master-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins_master" {
  name = "jenkins-master-profile-${var.environment}"
  role = aws_iam_role.jenkins_master.name
}

resource "aws_iam_role_policy" "jenkins_secrets_access" {
  name = "jenkins-secrets-access-${var.environment}"
  role = aws_iam_role.jenkins_master.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.jenkins_ssh_key_secret_arn]
      }
    ]
  })
} 