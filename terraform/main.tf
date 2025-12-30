provider "aws" {
  region = "us-east-1" # Choose your AWS region
}

# S3 Bucket for Website Hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.environment}-website-bucket"

  tags = {
    Name        = "${var.environment}-website-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_acl" "website_bucket_acl" {
  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "website_bucket_website" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_versioning" "website_bucket_versioning" {
  bucket = aws_s3_bucket.website_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for Logs
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "${var.environment}-logs-bucket"

  tags = {
    Name        = "${var.environment}-logs-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_acl" "logs_bucket_acl" {
  bucket = aws_s3_bucket.logs_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "logs_bucket_versioning" {
  bucket = aws_s3_bucket.logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "app_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website_bucket_website.website_endpoint
    origin_id   = "S3Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
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

  logging_config {
    bucket = aws_s3_bucket.logs_bucket.bucket_domain_name
    prefix = "${var.environment}/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.environment}-cloudfront-distribution"
    Environment = var.environment
  }
}