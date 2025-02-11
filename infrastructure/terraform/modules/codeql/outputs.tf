# Instance outputs
output "instance_id" {
  description = "ID of the CodeQL EC2 instance"
  value       = aws_instance.codeql.id
}

output "public_ip" {
  description = "Public IP address of the CodeQL EC2 instance"
  value       = aws_instance.codeql.public_ip
}

# Networking outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = var.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = var.subnet_id
}

output "security_group_id" {
  description = "ID of the CodeQL security group"
  value       = aws_security_group.codeql.id
}

# IAM outputs
output "iam_role_id" {
  description = "ID of the CodeQL IAM role"
  value       = aws_iam_role.codeql.id
}

output "iam_role_arn" {
  description = "ARN of the CodeQL IAM role"
  value       = aws_iam_role.codeql.arn
} 