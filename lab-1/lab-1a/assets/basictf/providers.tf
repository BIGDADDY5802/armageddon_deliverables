
terraform {
  backend "s3" {
    bucket = "11-9-backend"
    key    = "1c/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}
