# DynamoDB table for otp_verification
resource "aws_dynamodb_table" "PreliminaryOrders" {
  name           = "PreliminaryOrders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  depends_on = [aws_s3_bucket.web_app, aws_s3_bucket.web_app]
  
}

# DynamoDB table for confirmed_orders
resource "aws_dynamodb_table" "ConfirmedOrders" {
  name           = "ConfirmedOrders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

}
