# cors.tf

# OPTIONS method for CORS
resource "aws_api_gateway_method" "api_cors_options_method" {
  for_each      = toset(keys(local.lambda_endpoints))
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integration for OPTIONS method
resource "aws_api_gateway_integration" "api_cors_options_integration" {
  for_each    = toset(keys(local.lambda_endpoints))
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.api_resource[each.key].id
  http_method = "OPTIONS"
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\" : 200}"
  }
  depends_on = [aws_api_gateway_method.api_cors_options_method]
}

# Method Response for OPTIONS
resource "aws_api_gateway_method_response" "api_cors_options_method_response" {
  for_each     = toset(keys(local.lambda_endpoints))
  rest_api_id  = aws_api_gateway_rest_api.my_api.id
  resource_id  = aws_api_gateway_resource.api_resource[each.key].id
  http_method  = "OPTIONS"
  status_code  = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.api_cors_options_method]
}

# Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "api_cors_options_integration_response" {
  for_each     = toset(keys(local.lambda_endpoints))
  rest_api_id  = aws_api_gateway_rest_api.my_api.id
  resource_id  = aws_api_gateway_resource.api_resource[each.key].id
  http_method  = "OPTIONS"
  status_code  = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.api_cors_options_method_response]
}

# Method Response for POST
resource "aws_api_gateway_method_response" "api_cors_post_method_response" {
  for_each     = toset(keys(local.lambda_endpoints))
  rest_api_id  = aws_api_gateway_rest_api.my_api.id
  resource_id  = aws_api_gateway_resource.api_resource[each.key].id
  http_method  = "POST"
  status_code  = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.api_method]
}

# Integration Response for POST method to handle CORS headers
resource "aws_api_gateway_integration_response" "api_cors_post_integration_response" {
  for_each     = toset(keys(local.lambda_endpoints))
  rest_api_id  = aws_api_gateway_rest_api.my_api.id
  resource_id  = aws_api_gateway_resource.api_resource[each.key].id
  http_method  = "POST"
  status_code  = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.api_cors_post_method_response]
}

# Definition of the "prod" stage
resource "aws_api_gateway_stage" "prod_stage" {
  deployment_id = aws_api_gateway_deployment.my_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  stage_name    = "prod"
}

# Deployment of the API
resource "aws_api_gateway_deployment" "my_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id

  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_rest_api.my_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  # Ensure deployment happens after all methods, integrations, and responses are created
  depends_on = [
    aws_api_gateway_method.api_cors_options_method,
    aws_api_gateway_integration.api_cors_options_integration,
    aws_api_gateway_integration_response.api_cors_options_integration_response,
    aws_api_gateway_method_response.api_cors_options_method_response,
    aws_api_gateway_method_response.api_cors_post_method_response,
    aws_api_gateway_integration_response.api_cors_post_integration_response
  ]
}
