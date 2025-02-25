resource "aws_api_gateway_rest_api" "security_scan" {
  name        = "security-scan-api-${var.environment}"
  description = "API for triggering security scans"
}

resource "aws_api_gateway_resource" "scan" {
  rest_api_id = aws_api_gateway_rest_api.security_scan.id
  parent_id   = aws_api_gateway_rest_api.security_scan.root_resource_id
  path_part   = "scan"
}

resource "aws_api_gateway_method" "post_scan" {
  rest_api_id   = aws_api_gateway_rest_api.security_scan.id
  resource_id   = aws_api_gateway_resource.scan.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_lambda_function" "trigger_scan" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "security-scan-trigger-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30
  layers          = [aws_lambda_layer_version.dependencies_layer.arn]

  environment {
    variables = {
      JENKINS_URL      = var.jenkins_url
      JENKINS_API_TOKEN_SECRET_ARN = var.jenkins_api_token_secret_arn
      SCAN_QUEUE_URL   = var.scan_queue_url
      USE_QUEUE        = "true"
      SECURITY_SCANNER_URL = var.security_scanner_url
    }
  }
}

# API Gateway integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.security_scan.id
  resource_id = aws_api_gateway_resource.scan.id
  http_method = aws_api_gateway_method.post_scan.http_method
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.trigger_scan.invoke_arn
  integration_http_method = "POST"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_scan.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.security_scan.execution_arn}/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "security_scan" {
  rest_api_id = aws_api_gateway_rest_api.security_scan.id
  
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.security_scan.id
  rest_api_id   = aws_api_gateway_rest_api.security_scan.id
  stage_name    = "prod"
} 