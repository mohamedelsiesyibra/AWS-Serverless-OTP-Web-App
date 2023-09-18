# Define the IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  # Policy that allows Lambda and API Gateway to assume the role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "apigateway.amazonaws.com"  # Added the API Gateway service
          ]
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

# Attach the default AWS Lambda execution policy to our role
resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Define a policy that allows sending messages with SNS
resource "aws_iam_role_policy" "sns_full_access" {
  name = "SNSFullAccessForOTP"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sns:Publish"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# IAM Policy allowing Lambda to PutItem on both DynamoDB tables
resource "aws_iam_role_policy" "dynamodb_access_policy" {
  name = "DynamoDBFullAccessForLambda"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem"  
        ],
        Effect   = "Allow",
        Resource = [
          aws_dynamodb_table.PreliminaryOrders.arn,
          aws_dynamodb_table.ConfirmedOrders.arn
        ]
      }
    ]
  })
}



# Package the Lambda scripts into zip files for deployment
data "archive_file" "order_request_zip" {
  type        = "zip"
  source_file = "../lambda-scripts/order-request.py"
  output_path = "../lambda-scripts-zipped/order-request.zip"
}

data "archive_file" "otp_verification_zip" {
  type        = "zip"
  source_file = "../lambda-scripts/otp-verification.py"
  output_path = "../lambda-scripts-zipped/otp-verification.zip"
}

# Lambda functions
resource "aws_lambda_function" "order_request_lambda" {
  function_name    = "order-request"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "order-request.lambda_handler"
  filename         = data.archive_file.order_request_zip.output_path
  runtime          = "python3.8"
  source_code_hash = filebase64sha256(data.archive_file.order_request_zip.output_path)

  depends_on = [aws_iam_role_policy.sns_full_access]

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

resource "aws_lambda_function" "otp_verification_lambda" {
  function_name    = "otp-verification"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "otp-verification.lambda_handler"
  filename         = data.archive_file.otp_verification_zip.output_path
  runtime          = "python3.8"
  source_code_hash = filebase64sha256(data.archive_file.otp_verification_zip.output_path)

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# Outputs
output "otp_verification_lambda_arn" {
  value = aws_lambda_function.otp_verification_lambda.arn
  description = "ARN of the OTP Verification Lambda function"
}

output "order_request_lambda_arn" {
  value = aws_lambda_function.order_request_lambda.arn
  description = "ARN of the Order Request Lambda function"
}
