## TODO
Jenkins JCasC set up to automatically configure SQS queue processor and api-triggered-scan jobs and credentials

# Jenkins Module

This Terraform module deploys a Jenkins master server on AWS EC2, pre-configured with CodeQL integration and essential plugins.

## Features

- Deploys a Jenkins master server on EC2
- Automatically installs and configures Jenkins
- Pre-installs necessary plugins including CodeQL integration
- Sets up security groups for Jenkins access
- Uses Amazon Linux 2023 with Java 17
- Includes CodeQL CLI installation

## Requirements

- Terraform >= 1.0
- AWS provider
- An existing VPC and subnet
- An SSH key pair in AWS

## Usage
```hcl
module "jenkins" {
source = "./modules/jenkins"
vpc_id = "vpc-xxxxx"
subnet_id = "subnet-xxxxx"
environment = "dev"
key_name = "your-key-name"
admin_cidr_blocks = ["10.0.0.0/16"]
tags = {
Environment = "dev"
Project = "ci-cd"
}
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | ID of the VPC to use | string | - | yes |
| subnet_id | ID of the subnet to use | string | - | yes |
| environment | Environment name (e.g., dev, prod) | string | - | yes |
| key_name | Name of the SSH key pair | string | - | yes |
| admin_cidr_blocks | CIDR blocks for administrative access | list(string) | - | yes |
| jenkins_master_instance_type | Instance type for Jenkins master | string | "t3.large" | no |
| allowed_outbound_cidr_blocks | CIDR blocks for outbound traffic | list(string) | ["0.0.0.0/0"] | no |

## Outputs

| Name | Description |
|------|-------------|
| jenkins_master_public_ip | Public IP of Jenkins master |
| jenkins_url | URL for Jenkins master |
| jenkins_master_private_ip | Private IP of Jenkins master |
| jenkins_master_security_group_id | Security group ID of Jenkins master |

## Initial Setup

1. After deployment, access Jenkins at `http://<jenkins_master_public_ip>:8080`
2. Get the initial admin password from the EC2 instance:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. Complete the initial Jenkins setup wizard

## Pre-installed Plugins

- dependency-check-jenkins-plugin
- codeql
- workflow-aggregator
- git
- pipeline-utility-steps
- configuration-as-code

## Security Considerations

- Restrict admin_cidr_blocks to specific IP ranges in production
- Jenkins runs on port 8080 by default
- Instance uses Amazon Linux 2023 with latest security updates
- Consider setting up HTTPS with a proper certificate for production use