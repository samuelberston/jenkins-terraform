resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = var.key_name
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# Save the private key to a local file (be careful with this in production!)
resource "local_file" "private_key" {
  content  = tls_private_key.jenkins_key.private_key_pem
  filename = "${path.module}/jenkins-key.pem"

  # Set file permissions to 400 (read-only for owner)
  provisioner "local-exec" {
    command = "chmod 400 ${path.module}/jenkins-key.pem"
  }
} 