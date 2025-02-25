variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "jenkins_url" {
  description = "URL of the Jenkins instance"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "security_scanner_url" {
  description = "URL of the security scanner instance"
  type        = string
  default     = ""
}

variable "scan_queue_url" {
  description = "URL of the SQS queue for scan jobs"
  type        = string
}

variable "scan_queue_arn" {
  description = "ARN of the SQS queue for scan jobs"
  type        = string
}

variable "jenkins_api_token_secret_arn" {
  description = "ARN of the secret containing the Jenkins API token"
  type        = string
  default     = ""
} 