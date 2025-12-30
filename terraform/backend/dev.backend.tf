terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "devel/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}