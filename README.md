# Infrastructure as Code - Jenkins with CodeQL Integration

This project provides Infrastructure as Code (IaC) for deploying a secure CI/CD environment with Jenkins and CodeQL integration on AWS. The infrastructure is managed using Terraform and includes a shared VPC, Jenkins master server, and CodeQL analysis server.

## Architecture Overview

The infrastructure consists of:
- Shared VPC with public and private subnets across multiple availability zones
- Jenkins master server in a public subnet
- CodeQL analysis server in a public subnet
- Security groups controlling access between components
- IAM roles and policies for AWS service integration
- AWS Secrets Manager for SSH key storage

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- SSH key pair for instance access
- Git

## Quick Start

1. Clone this repository:
```bash
git clone <repository-url>
cd infrastructure/terraform
```

2. Configure your environment:
```bash
# Copy and modify the example tfvars file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables according to your needs
vim terraform.tfvars
```

3. Initialize and apply the Terraform configuration:
```bash
terraform init
terraform plan
terraform apply
```

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| environment | Environment name (e.g., dev, prod) |
| aws_region | AWS region for deployment |
| key_name | Name of the SSH key pair |
| admin_cidr_blocks | List of CIDR blocks for administrative access |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| vpc_cidr | CIDR block for VPC | 10.0.0.0/16 |
| availability_zones | List of AZs | ["us-west-1b", "us-west-1c"] |
| private_subnets | List of private subnet CIDRs | ["10.0.1.0/24", "10.0.2.0/24"] |
| public_subnets | List of public subnet CIDRs | ["10.0.101.0/24", "10.0.102.0/24"] |

## Components

### Jenkins Master

- Runs on Amazon Linux 2023
- Pre-installed with Java 17
- Includes essential plugins for CI/CD and CodeQL integration
- Accessible via port 8080
- Initial admin password stored in `/var/lib/jenkins/secrets/initialAdminPassword`

### CodeQL Server

- Dedicated instance for code analysis
- Pre-installed with CodeQL CLI
- Integrated with Jenkins for automated analysis
- Supports multiple programming languages (Java, Python, JavaScript, C++)

## Security Features

- IMDSv2 required on all instances
- SSH key pairs managed through AWS Secrets Manager
- Security groups with principle of least privilege
- VPC isolation with controlled ingress/egress
- Encrypted root volumes

## Jenkins Pipeline

A sample Jenkins pipeline for CodeQL analysis is included in `jenkins/jobs/codeql-analysis/Jenkinsfile`. This pipeline:
- Supports multiple programming languages
- Performs automated security analysis
- Generates SARIF reports
- Includes quality gates

## Maintenance

### Updating CodeQL

The CodeQL CLI version can be updated by modifying the `CODEQL_VERSION` variable in:
- `modules/jenkins/main.tf`
- `modules/codeql/main.tf`

### Backup Strategy

- Jenkins configuration and jobs are stored on the EBS volume
- Consider implementing regular EBS snapshots
- Use Jenkins Configuration as Code for version control

## Troubleshooting

1. Jenkins Access Issues:
   - Verify security group rules
   - Check instance health
   - Review Jenkins logs: `sudo tail -f /var/log/jenkins/jenkins.log`

2. CodeQL Analysis Failures:
   - Verify CodeQL CLI installation
   - Check language support
   - Review pipeline logs
