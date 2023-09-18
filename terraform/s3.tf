terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  content_types = {
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "svg"  = "image/svg+xml"
    # ... add any other file types you might be using
  }
}

# S3 bucket for the web app
resource "aws_s3_bucket" "web_app" {
  bucket = "moelsi-otp-web-app"

  website {
    index_document = "index.html"
  }
}

# Upload all files from web-app-scripts directory to the web app bucket
resource "aws_s3_bucket_object" "web_app_files_upload" {
  for_each = fileset("../web-app-files", "*")

  bucket       = aws_s3_bucket.web_app.bucket
  key          = each.value
  source       = "../web-app-files/${each.value}"
  content_type = lookup(local.content_types, trimspace(element(split(".", each.value), length(split(".", each.value)) - 1)), "application/octet-stream")
}

resource "aws_cloudfront_origin_access_identity" "web_oai" {
  comment = "Origin access identity for web app bucket"
}

# Configuring the public access block settings
resource "aws_s3_bucket_public_access_block" "web_app_access_block" {
  bucket = aws_s3_bucket.web_app.bucket

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

# CloudFront policy for the web app
resource "aws_s3_bucket_policy" "web_app_policy" {
  bucket = aws_s3_bucket.web_app.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::moelsi-otp-web-app/*"
        }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.web_app_access_block]
}
