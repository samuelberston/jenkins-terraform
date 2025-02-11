# Infrastructure as Code - Jenkins and CodeQL Setup

This Terraform configuration sets up a complete CI/CD and security scanning infrastructure on AWS, including Jenkins and CodeQL servers.

## Architecture

- Shared VPC with public and private subnets
- Jenkins master server with pre-installed plugins
- CodeQL server for code analysis
- Automated SSH key management via AWS Secrets Manager

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Access to AWS region us-west-1 (default, configurable)

## Quick Start

1. Initialize Terraform:
```bash
terraform init
```

2. Configure your environment:
```bash
# Copy and modify the example tfvars file
cp terraform.tfvars.example terraform.tfvars
```

3. Apply the configuration:
```bash
terraform apply
```

## Important Variables

| Variable | Description | Default |
|----------|-------------|---------|
| environment | Environment name (dev/prod) | - |
| aws_region | AWS region | us-west-1 |
| vpc_cidr | VPC CIDR block | 10.0.0.0/16 |
| admin_cidr_blocks | Allowed IPs for admin access | ["0.0.0.0/0"] |

## Security Notes

- Default security group settings allow access from anywhere (0.0.0.0/0)
- For production use:
  - Restrict admin_cidr_blocks to specific IP ranges
  - Enable VPN/bastion host access
  - Configure HTTPS endpoints

## Accessing Services

### Jenkins
- URL: http://<jenkins_ip>:8080
- Initial admin password location: `/var/lib/jenkins/secrets/initialAdminPassword`

### CodeQL
- SSH access: `ssh -i <key_path> ec2-user@<codeql_ip>`
- Pre-installed with latest CodeQL CLI and OWASP Dependency Check

## Maintenance

- SSH keys are automatically rotated and stored in AWS Secrets Manager
- Jenkins plugins are pre-installed and configured
- Daily automated updates for vulnerability databases

## Outputs

- Jenkins and CodeQL IP addresses
- Security group IDs
- SSH key information
- VPC and subnet IDs
