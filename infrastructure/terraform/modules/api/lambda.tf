# Create a layer for the requests library
resource "null_resource" "install_dependencies" {
  triggers = {
    requirements_md5 = filemd5("${path.module}/files/requirements.txt")
    lambda_code_md5 = filemd5("${path.module}/files/lambda/index.py")
  }

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.module}/files/layer/python
python3 -m pip install -r ${path.module}/files/requirements.txt -t ${path.module}/files/layer/python
EOF
  }
}

data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/files/layer"
  output_path = "${path.module}/files/layer.zip"
  depends_on  = [null_resource.install_dependencies]
}

resource "aws_lambda_layer_version" "dependencies_layer" {
  filename   = data.archive_file.layer_zip.output_path
  layer_name = "security-scan-dependencies-${var.environment}"
  
  compatible_runtimes = ["python3.9"]
  source_code_hash    = data.archive_file.layer_zip.output_base64sha256
}

# Create ZIP file for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/files/lambda"
  output_path = "${path.module}/files/lambda.zip"
}