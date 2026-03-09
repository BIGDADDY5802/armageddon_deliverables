# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# # Primary — Tokyo (ap-northeast-1)
# provider "aws" {
#   region = "ap-northeast-1"
# }

# # us-east-1 required for ACM certs used by CloudFront
# provider "aws" {
#   alias  = "useast1"
#   region = "us-east-1"
# }
