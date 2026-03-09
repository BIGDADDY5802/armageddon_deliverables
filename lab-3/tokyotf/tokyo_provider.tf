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

# us-east-1 required for ACM certs used by CloudFront
provider "aws" {
  alias  = "useast1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "saopaulo"
  region = "sa-east-1"
}