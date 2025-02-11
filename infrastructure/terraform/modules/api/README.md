# AWS API Gateway Security Scan Module

This Terraform module creates an API Gateway and Lambda function setup that enables triggering security scans through a RESTful API interface. The module integrates with Jenkins to initiate security scanning jobs.

## Features

- Serverless API Gateway endpoint with AWS IAM authentication
- Lambda function for processing scan requests
- Integration with Jenkins for triggering security scans
- Secure secret management for Jenkins API tokens
- Configurable environment-based deployments

## Usage
```hcl
module "security_scan_api" {
    source = "./modules/api"
    environment = "dev"
    jenkins_url = "https://jenkins.example.com"

    tags = {
        Environment = "dev"
        Project = "security-scanning"
    }
}
```


## Requirements

- AWS Provider
- Terraform >= 0.13
- Existing Jenkins instance with security scan job configured
- Jenkins API token stored in AWS Secrets Manager

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| environment | Environment name (e.g., dev, prod) | `string` | Yes |
| jenkins_url | URL of the Jenkins instance | `string` | Yes |
| tags | Resource tags | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_name | Name of the Lambda function |
| lambda_function_arn | ARN of the Lambda function |
| api_gateway_invoke_url | Invoke URL for the Lambda function via API Gateway |
| api_gateway_id | ID of the API Gateway |
| api_gateway_stage_name | Name of the API Gateway stage |
| api_gateway_endpoint | Full endpoint URL of the API |

## API Usage

### Endpoint

POST `/scan`

### Authentication

The API requires AWS IAM authentication. Ensure your requests are signed with appropriate AWS credentials.

### Request Body
```json
{
    "repository_url": "https://github.com/org/repo",
    "branch": "main", // Optional, defaults to "main"
    "language": "javascript", // Optional, defaults to "javascript"
    "scan_path": "." // Optional, defaults to "."
}
```


### Response

Success (202 Accepted):
```json
{
    "message": "Security scan triggered successfully",
    "queue_url": "https://jenkins.example.com/queue/item/123/"
}
```


## Initial Setup

1. Deploy the module using Terraform
2. Store the Jenkins API token in AWS Secrets Manager:
   ```bash
   aws secretsmanager put-secret-value \
     --secret-id jenkins-api-token-${environment} \
     --secret-string '{"token":"your-jenkins-api-token"}'
   ```
3. Ensure your Jenkins instance has a job named "security-scan" configured to accept the required parameters

## Security Considerations

- The API endpoint is secured with AWS IAM authentication
- Jenkins API token is stored securely in AWS Secrets Manager
- Lambda function has minimal IAM permissions
- All API requests are logged in CloudWatch
