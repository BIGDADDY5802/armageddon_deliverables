############################################
# Bonus B - Route53 Zone Apex + ALB Access Logs to S3
############################################

############################################
# Route53: Zone Apex (root domain) -> ALB
############################################

# Explanation: The zone apex is the throne room—dawgs-armageddon-growl.com itself should lead to the ALB.
resource "aws_route53_record" "dawgs-armageddon_apex_alias01" {
  zone_id = local.dawgs-armageddon_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.dawgs-armageddon_alb01.dns_name
    zone_id                = aws_lb.dawgs-armageddon_alb01.zone_id
    evaluate_target_health = true
  }
}

############################################
# S3 bucket for ALB access logs
############################################

# Explanation: This bucket is dawgs-armageddon’s log vault—every visitor to the ALB leaves footprints here.
resource "aws_s3_bucket" "dawgs-armageddon_alb_logs_bucket01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.dawgs-armageddon_self01.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-alb-logs-bucket01"
  }
}

# Explanation: Block public access—dawgs-armageddon does not publish the ship’s black box to the galaxy.
resource "aws_s3_bucket_public_access_block" "dawgs-armageddon_alb_logs_pab01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Bucket ownership controls prevent log delivery chaos—dawgs-armageddon likes clean chain-of-custody.
resource "aws_s3_bucket_ownership_controls" "dawgs-armageddon_alb_logs_owner01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Explanation: TLS-only—dawgs-armageddon growls at plaintext and throws it out an airlock.
resource "aws_s3_bucket_policy" "dawgs-armageddon_alb_logs_policy01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].id

  #   # NOTE: This is a skeleton. Students may need to adjust for region/account specifics.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].arn,
          "${aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "AllowELBRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root"  # This is the ELB service account for us-east-1
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].arn}/*"
      },
      {
        Sid    = "AllowELBGetBucketAcl"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].arn
      },
      {
        Sid    = "AllowELBPutObject"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.dawgs-armageddon_self01.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
# ############################################
# # Enable ALB access logs (on the ALB resource)
# ############################################

# # Explanation: Turn on access logs—dawgs-armageddon wants receipts when something goes wrong.
# # NOTE: This is a skeleton patch: students must merge this into aws_lb.dawgs-armageddon_alb01
# # by adding/accessing the `access_logs` block. Terraform does not support "partial" blocks.
# #
# # Add this inside resource "aws_lb" "dawgs-armageddon_alb01" { ... } in bonus_b.tf:
# #
# # access_logs {
# #   bucket  = aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].bucket
# #   prefix  = var.alb_access_logs_prefix
# #   enabled = var.enable_alb_access_logs
# # }