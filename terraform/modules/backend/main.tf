resource "aws_dynamodb_table" "environments" {
  name         = "${var.project_name}-environments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_security_group" "mender_environment" {
  name        = "${var.project_name}-mender-environment"
  description = "Allow HTTP/HTTPS traffic to Mender environments"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_api_gateway_rest_api" "default" {
  name        = "${var.project_name}-api"
  description = "API for MenderK8s"
}

resource "aws_api_gateway_resource" "environments" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  parent_id   = aws_api_gateway_rest_api.default.root_resource_id
  path_part   = "environments"
}

resource "aws_api_gateway_resource" "environment" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  parent_id   = aws_api_gateway_resource.environments.id
  path_part   = "{id}"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_permissions" {
  name        = "${var.project_name}-lambda-permissions"
  description = "Permissions for Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.environments.arn
      },
      {
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:CreateTags"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}

# Create zip file
data "archive_file" "lambda_create_environment" {
  type = "zip"

  source_dir  = "${path.cwd}/../src/lambda_create_environment"
  output_path = "${path.root}/../src/lambda_create_environment.zip"
}

# Create Environment Lambda
resource "aws_lambda_function" "create_environment" {
  function_name    = "${var.project_name}-create-environment"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "main.handler"
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_create_environment.output_path
  source_code_hash = data.archive_file.lambda_create_environment.output_base64sha256
  timeout          = 300

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.environments.name
      SECURITY_GROUP_ID = aws_security_group.mender_environment.id
    }
  }
}

# Create zip file
data "archive_file" "lambda_get_environments" {
  type = "zip"

  source_dir  = "${path.cwd}/../src/lambda_get_environments"
  output_path = "${path.root}/../src/lambda_get_environments.zip"
}

# Get Environments Lambda
resource "aws_lambda_function" "get_environments" {
  function_name    = "${var.project_name}-get-environments"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "main.handler"
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_get_environments.output_path
  source_code_hash = data.archive_file.lambda_get_environments.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.environments.name
    }
  }
}

# Create zip file
data "archive_file" "lambda_take_down_environment" {
  type = "zip"

  source_dir  = "${path.cwd}/../src/lambda_take_down_environment"
  output_path = "${path.root}/../src/lambda_take_down_environment.zip"
}

# Take Down Environment Lambda
resource "aws_lambda_function" "take_down_environment" {
  function_name    = "${var.project_name}-take-down-environment"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "main.handler"
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_take_down_environment.output_path
  source_code_hash = data.archive_file.lambda_take_down_environment.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.environments.name
    }
  }
}

# API Gateway Methods and Integrations

# POST /environments
resource "aws_api_gateway_method" "create_environment" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.environments.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_environment" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.create_environment.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_environment.invoke_arn
}

# GET /environments
resource "aws_api_gateway_method" "get_environments" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.environments.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_environments" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.get_environments.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_environments.invoke_arn
}

# DELETE /environments/{id}
resource "aws_api_gateway_method" "delete_environment" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.environment.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_environment" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environment.id
  http_method = aws_api_gateway_method.delete_environment.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.take_down_environment.invoke_arn
}

# CORS OPTIONS for /environments
resource "aws_api_gateway_method" "options_environments" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.environments.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_environments" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.options_environments.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_environments_200" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.options_environments.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_environments_200" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.options_environments.http_method
  status_code = aws_api_gateway_method_response.options_environments_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# CORS OPTIONS for /environments/{id}
resource "aws_api_gateway_method" "options_environment" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.environment.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_environment" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environment.id
  http_method = aws_api_gateway_method.options_environment.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_environment_200" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environment.id
  http_method = aws_api_gateway_method.options_environment.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_environment_200" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.environment.id
  http_method = aws_api_gateway_method.options_environment.http_method
  status_code = aws_api_gateway_method_response.options_environment_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda Permissions
resource "aws_lambda_permission" "create" {
  statement_id  = "AllowAPIGatewayToInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_environment.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.default.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get" {
  statement_id  = "AllowAPIGatewayToInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_environments.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.default.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete" {
  statement_id  = "AllowAPIGatewayToInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.take_down_environment.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.default.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.environments.id,
      aws_api_gateway_method.create_environment.id,
      aws_api_gateway_integration.create_environment.id,
      aws_api_gateway_method.get_environments.id,
      aws_api_gateway_integration.get_environments.id,
      aws_api_gateway_resource.environment.id,
      aws_api_gateway_method.delete_environment.id,
      aws_api_gateway_integration.delete_environment.id,
      aws_api_gateway_method.options_environments.id,
      aws_api_gateway_integration.options_environments.id,
      aws_api_gateway_method.options_environment.id,
      aws_api_gateway_integration.options_environment.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "default" {
  deployment_id = aws_api_gateway_deployment.default.id
  rest_api_id   = aws_api_gateway_rest_api.default.id
  stage_name    = "v1"
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.default.invoke_url
}
