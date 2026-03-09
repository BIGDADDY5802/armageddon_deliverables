# data "aws_ami" "al2023" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["al2023-ami-*-x86_64"]
#   }
# }


data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_route53_zone" "thedawgs_zone" {
  name         = var.domain_name
  private_zone = false
}

# data "aws_lb" "tokyo_alb" {
#   name     = "shinjuku-alb01"
#   provider = aws.tokyo  # needs ap-northeast-1 provider alias
# }

# data "aws_lb" "saopaulo_alb" {
#   name     = "liberdade-alb01"
#   provider = aws.saopaulo  # needs sa-east-1 provider alias
# }

data "aws_secretsmanager_secret_version" "lab3_origin_secret" {
  secret_id = aws_secretsmanager_secret.lab3_origin_secret.id

  depends_on = [aws_secretsmanager_secret_version.lab3_origin_secret_version]
}

