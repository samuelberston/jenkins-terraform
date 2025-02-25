# Upload setup scripts to S3 bucket
resource "aws_s3_object" "security_scanner_setup" {
  bucket = var.setup_bucket
  key    = "security-scanner-setup.sh"
  content = templatefile("${path.module}/files/security-scanner-setup.sh.tpl", {
    scan_queue_url          = var.scan_queue_url
    github_token_secret_arn = var.github_token_secret_arn
    db_credentials_secret_arn = var.db_credentials_secret_arn
  })
  content_type = "text/x-shellscript"
}

resource "aws_s3_object" "scan_worker" {
  bucket = var.setup_bucket
  key    = "scan_worker.py"
  source = "${path.module}/files/scan_worker.py"
  content_type = "text/x-python"
} 