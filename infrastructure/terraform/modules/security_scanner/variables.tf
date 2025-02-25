variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.2xlarge"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 32
}

variable "vpc_id" {
  description = "ID of the VPC to use"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to use"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect via SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Warning: This allows access from anywhere, consider restricting in production
}

variable "allowed_http_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect via HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Warning: This allows access from anywhere, consider restricting in production
}

variable "allowed_https_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect via HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Warning: This allows access from anywhere, consider restricting in production
}

variable "db_credentials_secret_arn" {
  description = "ARN of the secret containing the database credentials"
  type        = string
}

variable "scan_queue_url" {
  description = "URL of the SQS queue for scan jobs"
  type        = string
}

variable "scan_queue_arn" {
  description = "ARN of the SQS queue for scan jobs"
  type        = string
}

variable "additional_iam_policies" {
  description = "List of additional IAM policy ARNs to attach to the security scanner role"
  type        = list(string)
  default     = []
}

variable "github_token_secret_arn" {
  description = "ARN of the secret containing the GitHub access token"
  type        = string
}

variable "setup_bucket" {
  description = "S3 bucket containing setup scripts"
  type        = string
} 