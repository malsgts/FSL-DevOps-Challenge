provider "aws" {
  region = "us-east-1" # Choose your AWS region
}

# Random ID for bucket name uniqueness
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Bucket for Website Hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.environment}-website-bucket-${random_id.suffix.hex}"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  versioning {
    enabled = true
  }

  tags = {
    Name        = "${var.environment}-website-bucket-${random_id.suffix.hex}"
    Environment = var.environment
  }
}

# S3 Bucket for Logs
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "${var.environment}-logs-bucket-${random_id.suffix.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name        = "${var.environment}-logs-bucket-${random_id.suffix.hex}"
    Environment = var.environment
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "app_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.website_endpoint
    origin_id   = "S3Origin"
  }

  default_cache_behavior {
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  enabled             = true
  default_root_object = "index.html"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    bucket = aws_s3_bucket.logs_bucket.bucket_domain_name
    prefix = "${var.environment}/"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.environment}-cloudfront-distribution"
    Environment = var.environment
  }
}