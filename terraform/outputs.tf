output "website_bucket_name" {
  value       = aws_s3_bucket.website_bucket.bucket
  description = "The name of the website S3 bucket"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.app_distribution.domain_name
  description = "The CloudFront domain name for the application"
}

output "logs_bucket_name" {
  value       = aws_s3_bucket.logs_bucket.bucket
  description = "The name of the logs S3 bucket"
}