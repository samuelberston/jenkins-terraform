resource "random_password" "master_password" {
  length  = 16
  special = true
}

resource "aws_db_subnet_group" "main" {
  name        = "rds-subnet-group-${var.environment}"
  subnet_ids  = var.subnet_ids
  description = "RDS subnet group for ${var.environment}"

  tags = merge(
    {
      Name        = "rds-subnet-group-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_security_group" "rds" {
  name        = "rds-sg-${var.environment}"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  # PostgreSQL access from allowed security groups
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "rds-sg-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_db_instance" "main" {
  identifier = "postgresql-${var.environment}"

  engine         = "postgres"
  engine_version = "17.2"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  multi_az               = var.environment == "prod" ? true : false
  publicly_accessible    = false
  skip_final_snapshot    = var.environment == "dev" ? true : false

  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn

  tags = merge(
    {
      Name        = "postgresql-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Create IAM role for enhanced monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "db-credentials-${var.environment}"
  description = "Database credentials for ${var.environment} environment"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    host     = aws_db_instance.main.endpoint
    port     = 5432
    dbname   = var.database_name
  })
}
