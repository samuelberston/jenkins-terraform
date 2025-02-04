output "jenkins_master_public_ip" {
  description = "Public IP of Jenkins master"
  value       = aws_instance.jenkins_master.public_ip
}

output "jenkins_url" {
  description = "URL for Jenkins master"
  value       = "http://${aws_instance.jenkins_master.public_ip}:8080"
} 