output "jenkins_master_public_ip" {
  description = "Public IP of Jenkins master"
  value       = aws_instance.jenkins_master.public_ip
}

output "jenkins_url" {
  description = "URL for Jenkins master"
  value       = "http://${aws_instance.jenkins_master.public_ip}:8080"
}

output "jenkins_master_private_ip" {
  description = "Private IP of Jenkins master"
  value       = aws_instance.jenkins_master.private_ip
}

output "jenkins_master_private_ip_cidr" {
  description = "CIDR block for Jenkins master private IP"
  value       = "${aws_instance.jenkins_master.private_ip}/32"
}

output "jenkins_master_security_group_id" {
  description = "Security group ID of Jenkins master"
  value       = aws_security_group.jenkins_master_sg.id
}

output "admin_password_secret_name" {
  description = "Name of the secret containing the Jenkins admin password"
  value       = aws_secretsmanager_secret.jenkins_admin_password.name
}

output "admin_password_secret_arn" {
  description = "ARN of the secret containing the Jenkins admin password"
  value       = aws_secretsmanager_secret.jenkins_admin_password.arn
}

output "jenkins_admin_password" {
  description = "Command to retrieve the Jenkins admin password (dev environment only)"
  value       = var.environment == "dev" ? "aws secretsmanager get-secret-value --secret-id jenkins-admin-password-${var.environment} --query 'SecretString' --output text" : "Password retrieval disabled in this environment"
  depends_on  = [aws_ssm_association.verify_jenkins]
} 