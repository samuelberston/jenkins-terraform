output "codeql_instance_id" {
  description = "ID of the CodeQL instance"
  value       = module.codeql.instance_id
}

output "codeql_public_ip" {
  description = "Public IP of the CodeQL instance"
  value       = module.codeql.public_ip
}

output "codeql_subnet_id" {
  description = "Subnet ID where CodeQL is deployed"
  value       = module.codeql.subnet_id
}

output "codeql_security_group_id" {
  description = "Security Group ID for CodeQL"
  value       = module.codeql.security_group_id
}

output "ssh_key_name" {
  description = "Name of the generated SSH key pair"
  value       = aws_key_pair.jenkins_key.key_name
}

output "ssh_key_secret_name" {
  description = "Name of the secret containing the SSH private key"
  value       = aws_secretsmanager_secret.jenkins_key.name
} 