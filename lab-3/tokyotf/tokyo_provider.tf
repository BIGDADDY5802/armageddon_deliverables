terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Tokyo is the default provider — all resources in this state deploy to ap-northeast-1.
provider "aws" {
  region = "ap-northeast-1"
}
