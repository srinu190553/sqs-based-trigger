provider "aws" {
  region = "us-east-1"  # Update with your desired AWS region
}

terraform {
  backend "s3" {
    bucket         = "sqs-trigger-terraform"
    key            = "sqs-trigger-terraform/terraform.tfstate"  # Update with your desired state file name
    region         = "us-east-1"           # Update with your desired AWS region
    encrypt        = true
  }
}
