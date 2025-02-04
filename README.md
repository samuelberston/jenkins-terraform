# Jenkins Infrastructure on AWS

This project contains Terraform configurations to deploy a Jenkins master server on AWS, complete with VPC networking and security configurations.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0.0)
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Basic understanding of AWS services (VPC, EC2, Security Groups)

## Infrastructure Components

- VPC with public and private subnets
- NAT Gateway for private subnet internet access
- Jenkins master EC2 instance in a public subnet
- Security group for Jenkins master
- SSH key pair for instance access

## Quick Start

1. Clone this repository:
```
bash
git clone <repository-url>
cd infrastructure/terraform
```


2. Initialize Terraform:
```bash
terraform init
```

3. Review the configuration:
```bash
terraform plan
```

4. Apply the configuration:
```bash
terraform apply
```


5. Access Jenkins:
   - Wait a few minutes for the instance to initialize
   - Access Jenkins UI using the output URL
   - Get the initial admin password:
     ```bash
     ssh -i jenkins-key.pem ec2-user@<instance-ip>
     sudo cat /var/lib/jenkins/secrets/initialAdminPassword
     ```

## Configuration

Key configuration variables can be modified in `variables.tf`:

- `aws_region`: AWS region for deployment (default: us-west-1)
- `environment`: Environment name (default: production)
- `vpc_cidr`: VPC CIDR range (default: 10.0.0.0/16)
- `admin_cidr_blocks`: CIDR blocks for SSH access
- `jenkins_master_instance_type`: EC2 instance type (default: t3.medium)

## Security Considerations

1. The default `admin_cidr_blocks` is set to "0.0.0.0/0". For production, restrict this to your specific IP range.
2. Jenkins is exposed on port 8080. Consider using HTTPS with AWS Certificate Manager.
3. The SSH key is generated and stored locally. Ensure proper key management in production.

## Outputs

- `jenkins_master_public_ip`: Public IP of the Jenkins instance
- `jenkins_url`: URL to access Jenkins UI

## Clean Up

To destroy the infrastructure:
```bash
terraform destroy
```