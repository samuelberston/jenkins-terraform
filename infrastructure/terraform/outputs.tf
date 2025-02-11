output "security_scanner_instance_id" {
  description = "ID of the Security Scanner instance"
  value       = module.security_scanner.instance_id
}

output "security_scanner_public_ip" {
  description = "Public IP of the Security Scanner instance"
  value       = module.security_scanner.public_ip
}

output "security_scanner_subnet_id" {
  description = "Subnet ID where Security Scanner is deployed"
  value       = module.security_scanner.subnet_id
}

output "security_scanner_security_group_id" {
  description = "Security Group ID for Security Scanner"
  value       = module.security_scanner.security_group_id
}

output "ssh_key_name" {
  description = "Name of the generated SSH key pair"
  value       = aws_key_pair.jenkins_key.key_name
}

output "ssh_key_secret_name" {
  description = "Name of the secret containing the SSH private key"
  value       = aws_secretsmanager_secret.jenkins_key.name
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins instance"
  value       = module.jenkins.jenkins_master_public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins instance"
  value       = module.jenkins.jenkins_master_private_ip
}

output "jenkins_private_ip_cidr" {
  description = "CIDR block for Jenkins master private IP"
  value       = module.jenkins.jenkins_master_private_ip_cidr
}

output "jenkins_url" {
  description = "URL for Jenkins master"
  value       = module.jenkins.jenkins_url
}

output "jenkins_security_group_id" {
  description = "Security Group ID for Jenkins"
  value       = module.jenkins.jenkins_master_security_group_id
}

output "security_scanner_ssh_command" {
  description = "Command to SSH into the Security Scanner instance"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.jenkins_key.name} --query 'SecretString' --output text > jenkins-key.pem && chmod 400 jenkins-key.pem && ssh -i jenkins-key.pem ec2-user@${module.security_scanner.public_ip}"
}

output "jenkins_ssh_command" {
  description = "Command to SSH into the Jenkins instance"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.jenkins_key.name} --query 'SecretString' --output text > jenkins-key.pem && chmod 400 jenkins-key.pem && ssh -i jenkins-key.pem ec2-user@${module.jenkins.jenkins_master_public_ip}"
} 