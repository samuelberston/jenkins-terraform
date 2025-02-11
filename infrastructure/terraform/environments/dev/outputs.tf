# Re-export all outputs from the root module
output "security_scanner_instance_id" {
  description = "ID of the Security Scanner instance"
  value       = module.base_infrastructure.security_scanner_instance_id
}

output "security_scanner_public_ip" {
  description = "Public IP of the Security Scanner instance"
  value       = module.base_infrastructure.security_scanner_public_ip
}

output "security_scanner_subnet_id" {
  description = "Subnet ID where Security Scanner is deployed"
  value       = module.base_infrastructure.security_scanner_subnet_id
}

output "security_scanner_security_group_id" {
  description = "Security Group ID for Security Scanner"
  value       = module.base_infrastructure.security_scanner_security_group_id
}

output "ssh_key_name" {
  description = "Name of the generated SSH key pair"
  value       = module.base_infrastructure.ssh_key_name
}

output "ssh_key_secret_name" {
  description = "Name of the secret containing the SSH private key"
  value       = module.base_infrastructure.ssh_key_secret_name
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins instance"
  value       = module.base_infrastructure.jenkins_public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins instance"
  value       = module.base_infrastructure.jenkins_private_ip
}

output "jenkins_private_ip_cidr" {
  description = "CIDR block for Jenkins master private IP"
  value       = module.base_infrastructure.jenkins_private_ip_cidr
}

output "jenkins_url" {
  description = "URL for Jenkins master"
  value       = module.base_infrastructure.jenkins_url
}

output "jenkins_security_group_id" {
  description = "Security Group ID for Jenkins"
  value       = module.base_infrastructure.jenkins_security_group_id
}

output "security_scanner_ssh_command" {
  description = "Command to SSH into the Security Scanner instance"
  value       = module.base_infrastructure.security_scanner_ssh_command
}

output "jenkins_ssh_command" {
  description = "Command to SSH into the Jenkins instance"
  value       = module.base_infrastructure.jenkins_ssh_command
} 