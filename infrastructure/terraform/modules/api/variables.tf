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