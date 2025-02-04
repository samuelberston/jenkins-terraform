variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1c"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks for SSH access"
  type        = string
  default     = "0.0.0.0/0"  # Change this to your IP range for security
}

variable "jenkins_master_ami" {
  description = "AMI ID for Jenkins master (Amazon Linux 2023)"
  type        = string
  default     = "ami-08d4f6bbae664bd41"  # Amazon Linux 2023 AMI in us-west-1
}

variable "jenkins_master_instance_type" {
  description = "Instance type for Jenkins master"
  type        = string
  default     = "t3.medium"  # Recommended for Jenkins production use
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "jenkins-key"
}