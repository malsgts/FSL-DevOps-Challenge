bucket         = "terraform-state-bucket"
key            = "stage/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"