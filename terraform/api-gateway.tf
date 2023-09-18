# api-gateway.tf

# Create API Gateway resources
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "my-otp-app-api"
  description = "My OTP APIs service"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Local value for lambda_endpoints
locals {
  lambda_endpoints = {
    "otp-verification" = aws_lambda_function.otp_verification_lambda.arn
    "order-request"    = aws_lambda_function.order_request_lambda.arn
  }
}

resource "aws_api_gateway_resource" "api_resource" {
  for_each   = local.lambda_endpoints
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "api_method" {
  for_each      = local.lambda_endpoints
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_integration" {
  for_each    = local.lambda_endpoints
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.api_resource[each.key].id
  http_method = "POST"
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${each.value}/invocations"
  credentials = aws_iam_role.lambda_execution_role.arn

  depends_on = [aws_api_gateway_method.api_method]
}


resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

# Fetch the current region
data "aws_region" "current" {}

# Fetch the current account ID
data "aws_caller_identity" "current" {}

# Store API endpoint URLs in S3 in JSON format
resource "aws_s3_bucket_object" "api_urls" {
  bucket = "moelsi-otp-web-app"
  
  key    = "api_urls.json"
  content = jsonencode({
    "otp-verification" = "https://${aws_api_gateway_rest_api.my_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod/otp-verification",
    "order-request"    = "https://${aws_api_gateway_rest_api.my_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod/order-request"
  })
}

# Permissions for API Gateway to trigger each Lambda function
resource "aws_lambda_permission" "api_gateway_permission" {
  for_each = local.lambda_endpoints
  
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.my_api.id}/*/*/${each.key}"
}

