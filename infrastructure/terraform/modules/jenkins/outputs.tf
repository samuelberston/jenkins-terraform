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