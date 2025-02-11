output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.trigger_scan.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.trigger_scan.arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL for the Lambda function via API Gateway"
  value       = "${aws_api_gateway_rest_api.security_scan.execution_arn}/*/POST/scan"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.security_scan.id
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = "dev"  # You might want to make this configurable via variables
}

output "api_gateway_endpoint" {
  description = "Full endpoint URL of the API"
  value       = "${aws_api_gateway_rest_api.security_scan.execution_arn}/prod/scan"
} 