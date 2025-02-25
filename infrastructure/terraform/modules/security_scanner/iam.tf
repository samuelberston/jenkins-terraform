resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_iam_role" "security_scanner" {
  name = "security-scanner-role-${var.environment}-${random_id.suffix.hex}"

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

  tags = merge(
    {
      Name        = "security-scanner-role-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "security_scanner" {
  name = "security-scanner-profile-${var.environment}-${random_id.suffix.hex}"
  role = aws_iam_role.security_scanner.name
}

resource "aws_iam_role_policy" "security_scanner_db_access" {
  name = "security-scanner-db-access-${var.environment}"
  role = aws_iam_role.security_scanner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.db_credentials_secret_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_scanner_sqs_access" {
  name = "security-scanner-sqs-access-${var.environment}"
  role = aws_iam_role.security_scanner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = var.scan_queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_scanner_github_token_access" {
  name = "security-scanner-github-token-access-${var.environment}"
  role = aws_iam_role.security_scanner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.github_token_secret_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_scanner_s3_access" {
  name = "security-scanner-s3-access-${var.environment}"
  role = aws_iam_role.security_scanner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.setup_bucket}",
          "arn:aws:s3:::${var.setup_bucket}/*"
        ]
      }
    ]
  })
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = length(var.additional_iam_policies)
  role       = aws_iam_role.security_scanner.name
  policy_arn = var.additional_iam_policies[count.index]
} 