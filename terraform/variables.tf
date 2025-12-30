variable "environment" {
  description = "The environment to deploy (e.g., devel, stage)"
  type        = string
  default     = "devel"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}