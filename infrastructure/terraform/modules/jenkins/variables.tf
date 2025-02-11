variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks for administrative access"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to use"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to use"
  type        = string
}

variable "jenkins_master_instance_type" {
  description = "Instance type for Jenkins master"
  type        = string
  default     = "t3.large"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_outbound_cidr_blocks" {
  description = "CIDR blocks for outbound traffic"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Default allows all outbound traffic
}

variable "jenkins_ssh_key_secret_name" {
  description = "Name of the secret containing the Jenkins SSH private key"
  type        = string
}

variable "jenkins_ssh_key_secret_arn" {
  description = "ARN of the secret containing the Jenkins SSH private key"
  type        = string
}

variable "db_credentials_secret_arn" {
  description = "ARN of the secret containing the database credentials"
  type        = string
}