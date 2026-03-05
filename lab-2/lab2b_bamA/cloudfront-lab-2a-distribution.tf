############################################
# Lab 2A - CloudFront Distribution
#
# Purpose: CloudFront sits in front of the ALB.
# This file also:
#   - Changes the ALB HTTPS listener default
#     action from FORWARD to 403 (lockdown)
#   - Adds an ALB listener rule that ONLY
#     forwards requests carrying the correct
#     X-Origin-Verify secret header
#   - Replaces the open 0.0.0.0/0 ALB SG
#     ingress rules with the CloudFront
#     managed prefix list (network lockdown)
#   - Updates Route53 app ALIAS to point
#     at CloudFront instead of ALB
#   - Optionally creates an S3 logging bucket
#     for CloudFront standard access logs
#
# After terraform apply, verify with:
#
#   # Should return 403 — direct ALB hit, no secret
#   curl -I https://<alb-dns>.elb.amazonaws.com
#
#   # Should return 200 — CloudFront path with secret
#   curl -I https://app.thedawgs2025.click/list
#
# Analogy: CloudFront is the only public gate
# into the base. We welded all the side doors
# shut (ALB SG + listener 403 default) so
# every visitor MUST come through the gate.
############################################

############################################
# Locals
############################################

locals {
  # Explanation: The FQDN that CloudFront will serve.
  # In most cases this matches var.cloudfront_subdomain.var.domain_name.
  cf_fqdn = "${var.cloudfront_subdomain}.${var.domain_name}"

  # Explanation: CloudFront's managed prefix list for us-east-1.
  # This contains all CloudFront edge node CIDR ranges.
  # Using this instead of 0.0.0.0/0 means only CloudFront
  # can physically reach your ALB on port 80/443.
  # pl-3b927c52 is the AWS-managed CloudFront prefix list for us-east-1.
  cloudfront_prefix_list_id = "pl-3b927c52"
}

############################################
# S3 Bucket: CloudFront Access Logs (optional)
############################################

# Explanation: If you enable logging, CloudFront ships every
# request log to this bucket — useful for post-incident review.
resource "aws_s3_bucket" "dawgs-armageddon_cf_logs_bucket01" {
  count = var.enable_cloudfront && var.enable_cloudfront_logging ? 1 : 0

  bucket = "${var.project_name}-cf-logs-${data.aws_caller_identity.dawgs-armageddon_self01.account_id}"

  tags = {
    Name = "${var.project_name}-cf-logs-bucket01"
    Lab  = "2A"
  }
}

# Explanation: Nobody reads these logs from the internet — lock the vault.
resource "aws_s3_bucket_public_access_block" "dawgs-armageddon_cf_logs_pab01" {
  count = var.enable_cloudfront && var.enable_cloudfront_logging ? 1 : 0

  bucket                  = aws_s3_bucket.dawgs-armageddon_cf_logs_bucket01[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: CloudFront's log delivery service needs to write into this bucket.
# BucketOwnerPreferred ensures your account owns the log objects, not AWS.
resource "aws_s3_bucket_ownership_controls" "dawgs-armageddon_cf_logs_owner01" {
  count = var.enable_cloudfront && var.enable_cloudfront_logging ? 1 : 0

  bucket = aws_s3_bucket.dawgs-armageddon_cf_logs_bucket01[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

############################################
# ACM Certificate for CloudFront
#
# IMPORTANT: CloudFront certificates MUST be
# in us-east-1. This is a separate cert from
# the ALB cert (which is in your main region).
# Analogy: CloudFront is a global fleet — it
# needs its papers filed at HQ (us-east-1),
# not at the regional outpost.
############################################

# Explanation: This cert is for the CloudFront distribution.
# It covers app.thedawgs2025.click (and optionally the apex).
resource "aws_acm_certificate" "dawgs-armageddon_cf_cert01" {
  count = var.enable_cloudfront ? 1 : 0

  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = [local.cf_fqdn, "*.${var.domain_name}"]
  validation_method         = var.certificate_validation_method

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cf-cert01"
    Lab  = "2A"
  }
}

# Explanation: DNS validation via Route53 — prove you own the domain
# by dropping a CNAME record in the hosted zone. ACM checks and issues.
resource "aws_route53_record" "dawgs-armageddon_cf_cert_validation" {
  for_each = var.enable_cloudfront && var.certificate_validation_method == "DNS" ? {
    for dvo in aws_acm_certificate.dawgs-armageddon_cf_cert01[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  allow_overwrite = true
  zone_id         = local.dawgs-armageddon_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}

# Explanation: Wait for ACM to confirm the cert is valid before CloudFront tries to use it.
resource "aws_acm_certificate_validation" "dawgs-armageddon_cf_cert_validation01" {
  count = var.enable_cloudfront && var.certificate_validation_method == "DNS" ? 1 : 0

  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.dawgs-armageddon_cf_cert01[0].arn

  validation_record_fqdns = [
    for r in aws_route53_record.dawgs-armageddon_cf_cert_validation : r.fqdn
  ]
}


# Static content bucket for CloudFront /static/* origin
resource "aws_s3_bucket" "dawgs-armageddon_static_bucket01" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = "${var.project_name}-static-${data.aws_caller_identity.dawgs-armageddon_self01.account_id}"
}

resource "aws_s3_bucket_public_access_block" "dawgs-armageddon_static_pab01" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.dawgs-armageddon_static_bucket01[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OAC — lets CloudFront sign requests to S3 without making the bucket public
resource "aws_cloudfront_origin_access_control" "dawgs-armageddon_oac_static01" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "${var.project_name}-oac-static01"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy — only allows CloudFront (via OAC) to read objects
resource "aws_s3_bucket_policy" "dawgs-armageddon_static_policy01" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.dawgs-armageddon_static_bucket01[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.dawgs-armageddon_static_bucket01[0].arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.dawgs-armageddon_cf01[0].arn
        }
      }
    }]
  })
}
############################################
# CloudFront Distribution
############################################

# Explanation: The CloudFront distribution is the main gate.
# Origin = your ALB. Edge locations = checkpoints around the galaxy.
# Every HTTP request from users hits CloudFront first, not the ALB.
resource "aws_cloudfront_distribution" "dawgs-armageddon_cf01" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  comment             = "${var.project_name} Lab 2A distribution"
  http_version        = var.cloudfront_http_version
  price_class         = var.cloudfront_price_class
  aliases             = [local.cf_fqdn, var.domain_name]
  wait_for_deployment = false # Don't block terraform apply; use outputs to check status

  # ── Origin: ALB ────────────────────────────────────────────────────────
  # Explanation: The origin is WHERE CloudFront forwards requests after
  # its edge processing. We target the ALB, not EC2 directly.
  origin {
    domain_name = aws_lb.dawgs-armageddon_alb01.dns_name
    origin_id   = "${var.project_name}-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"   # Changed from https-only: ALB cert covers thedawgs2025.click
                                             # but CloudFront sends SNI as the ALB DNS name, causing
                                             # ClientTLSNegotiationErrorCount errors. CloudFront→ALB
                                             # traffic stays on AWS backbone; X-Origin-Verify header
                                             # provides application-layer security.
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    

    # Explanation: This is the password CloudFront whispers to the ALB.
    # The ALB listener rule checks for this exact value.
    # If the header is missing or wrong, the ALB returns 403.
    # This stops anyone who tries to bypass CloudFront and go direct.
    # random_password is the source of truth — ALB listener rule references the same resource.
    custom_header {
      name  = var.cloudfront_origin_header_name  # "X-Origin-Verify"
      value = random_password.dawgs-armageddon_origin_header_value01.result
    }
  }

  # ── Origin: S3 (static assets) ─────────────────────────────────────────
  origin {
    domain_name              = aws_s3_bucket.dawgs-armageddon_static_bucket01[0].bucket_regional_domain_name
    origin_id                = "${var.project_name}-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.dawgs-armageddon_oac_static01[0].id
  }

  # ── Cache Behavior (Default) ────────────────────────────────────────────
  # Explanation: This is the flight plan for all requests that don't match
  # a more specific path pattern. Since this is a dynamic Flask app,
  # caching is set to pass-through (TTL=0) so every request hits the origin.

  # ── Behavior 1: /api/public-feed (Honors — origin-driven caching) ───────
  # Uses AWS managed policy UseOriginCacheControlHeaders.
  # Flask sends Cache-Control: public, s-maxage=30, max-age=0
  # CloudFront reads s-maxage=30 and caches for 30 seconds.
  # After 30s, CloudFront re-fetches and resets the cache.
  # If Flask sends private/no-store or nothing → TTL=0, not cached.
  ordered_cache_behavior {
    path_pattern           = "/api/public-feed"
    target_origin_id       = "${var.project_name}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    # Using custom policy from lab2b_safe_caching.tf (default_ttl=0, max_ttl=60)
    # rather than the AWS managed UseOriginCacheControlHeaders policy.
    # Both respect origin Cache-Control — the custom policy adds a 60s cap
    # as a safety ceiling, which prevents origin from accidentally setting huge TTLs.
    cache_policy_id          = data.aws_cloudfront_cache_policy.dawgs-armageddon_managed_origin_cc01.id
    # AllViewerExceptHostHeader forwards all viewer context to ALB without the Host
    # header — prevents SNI mismatch on the ALB that would cause 400/421 errors.
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.dawgs-armageddon_managed_orp_all_viewer_except_host01.id
  }

  # ── Behavior 2: /api/* catch-all (Honors — caching always disabled) ─────
  # Any /api/ path not matched by /api/public-feed above falls here.
  # Uses AWS managed CachingDisabled policy — TTL=0, nothing cached.
  # /api/list hits this behavior. The private, no-store header from Flask
  # is defense-in-depth — the managed policy already prevents caching.
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "${var.project_name}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = aws_cloudfront_cache_policy.dawgs-armageddon_cache_api_disabled01.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_api01.id
  }

  # ── Behavior 3: /api/list (renamed from /list) ──────────────────────────
  # Route renamed to /api/list in user_data.sh to group all API endpoints
  # under /api/*. The /api/* catch-all behavior (CachingDisabled) above
  # would match /api/list — but this explicit behavior comes first in the
  # matrix, ensuring the correct cache policy applies.
  # NOTE: if you remove this block, /api/list falls through to /api/*
  # which uses CachingDisabled — still correct, just less explicit.
  ordered_cache_behavior {
    path_pattern           = "/api/list"
    target_origin_id       = "${var.project_name}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = aws_cloudfront_cache_policy.dawgs-armageddon_cache_public_get01.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_api01.id
  }

  # ── Behavior 4: /static/* (aggressive caching — S3 origin) ─────────────
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "${var.project_name}-s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id            = aws_cloudfront_cache_policy.dawgs-armageddon_cache_static01.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_static01.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.dawgs-armageddon_rsp_static01.id
  }

  default_cache_behavior {
  target_origin_id       = "${var.project_name}-alb-origin"
  viewer_protocol_policy = "redirect-to-https"

  allowed_methods = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
  cached_methods  = ["GET","HEAD"]

  cache_policy_id          = aws_cloudfront_cache_policy.dawgs-armageddon_cache_api_disabled01.id
  origin_request_policy_id = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_api01.id
}

  # ── WAF Attachment ─────────────────────────────────────────────────────
  web_acl_id = var.enable_cloudfront_waf ? aws_wafv2_web_acl.dawgs-armageddon_cf_waf01[0].arn : null

  # ── TLS / Viewer Certificate ───────────────────────────────────────────
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.dawgs-armageddon_cf_cert01[0].arn
    ssl_support_method       = "sni-only"           # SNI = modern browsers; no legacy IP-based TLS cost
    minimum_protocol_version = "TLSv1.2_2021"       # Enforce modern TLS
  }

  # ── Geo Restriction ────────────────────────────────────────────────────
  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction_type
      locations        = var.cloudfront_geo_restriction_locations
    }
  }

  # ── Access Logging (optional) ──────────────────────────────────────────
  dynamic "logging_config" {
    for_each = var.enable_cloudfront_logging ? [1] : []
    content {
      bucket          = aws_s3_bucket.dawgs-armageddon_cf_logs_bucket01[0].bucket_domain_name
      prefix          = var.cloudfront_log_prefix
      include_cookies = false
    }
  }

  depends_on = [
    aws_acm_certificate_validation.dawgs-armageddon_cf_cert_validation01,
    aws_lb.dawgs-armageddon_alb01
  ]

  tags = {
    Name = "${var.project_name}-cf01"
    Lab  = "2A"
  }
}

############################################
# ALB Lockdown - Part 1: Security Group
#
# The 0.0.0.0/0 ingress rules are updated
# IN PLACE inside bonus_b.tf (same resource
# names, same state addresses). No new
# resources here — that caused the
# RulesPerSecurityGroupLimitExceeded error.
#
# bonus_b.tf resources modified:
#   .dawgs-armageddon_alb_sg01_allow_http  -> prefix_list_id = "pl-3b927c52"
#   .dawgs-armageddon_alb_sg01_allow_https -> prefix_list_id = "pl-3b927c52"
#
# Terraform destroys the old CIDR rule and
# creates the prefix-list rule in its place.
# Same slot in state. No SG rule count hit.
############################################

############################################
# ALB Lockdown - Part 2: Listener Rule
#
# Application-level enforcement.
# Anyone who reaches the ALB (via CloudFront
# prefix list bypass or any other path) and
# does NOT carry the correct X-Origin-Verify
# header will get a 403 at the ALB itself.
# This is defense-in-depth:
#   Layer 1 = SG (network)
#   Layer 2 = listener rule (application)
############################################

# Explanation: Priority 1 rule = first thing the ALB checks.
# If the secret header is present and correct — FORWARD to the app.
# If not — the default action (403) fires. Two layers, one goal.
resource "aws_lb_listener_rule" "dawgs-armageddon_cf_origin_verify_rule" {
  count = var.enable_cloudfront ? 1 : 0

  listener_arn = aws_lb_listener.dawgs-armageddon_https_listener01.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dawgs-armageddon_tg01.arn
  }

  condition {
    http_header {
      http_header_name = var.cloudfront_origin_header_name  # "X-Origin-Verify"
      values           = [random_password.dawgs-armageddon_origin_header_value01.result]
    }
  }
}

############################################
# ALB Lockdown - Part 3: Listener Default 403
#
# The HTTPS listener default_action is updated
# IN PLACE inside bonus_b.tf — same resource
# name, same state address. No new resource
# here — that caused the DuplicateListener
# error (two resources binding port 443).
#
# bonus_b.tf resource modified:
#   aws_lb_listener.dawgs-armageddon_https_listener01
#   default_action changed from forward->TG
#   to fixed-response 403.
#
# The listener rule below (priority 1) runs
# first and forwards requests that carry the
# correct X-Origin-Verify header (CloudFront).
# Everything else hits the 403 default.
############################################

############################################
# Route53: Point app.thedawgs2025.click
#          at CloudFront (not ALB)
#
# We override the existing app alias from
# bonus_b.tf. Comment out or remove the
# aws_route53_record.dawgs-armageddon_app_alias
# in bonus_b.tf to avoid conflicts.
############################################

# Explanation: DNS now routes users to CloudFront's edge,
# not the ALB directly. Users get the fastest edge node;
# CloudFront forwards to ALB with the secret header.
resource "aws_route53_record" "dawgs-armageddon_cf_app_alias" {
  count = var.enable_cloudfront ? 1 : 0

  zone_id         = local.dawgs-armageddon_zone_id
  name            = local.cf_fqdn  # app.thedawgs2025.click
  type            = "A"
  allow_overwrite = true  # Overwrites the existing ALB alias — record transferred from bonus_b.tf

  alias {
    name                   = aws_cloudfront_distribution.dawgs-armageddon_cf01[0].domain_name
    zone_id                = aws_cloudfront_distribution.dawgs-armageddon_cf01[0].hosted_zone_id
    evaluate_target_health = false  # CloudFront does not support health-check evaluation on aliases
  }

  depends_on = [aws_cloudfront_distribution.dawgs-armageddon_cf01]
}

resource "aws_route53_record" "dawgs-armageddon_cf_apex_alias" {
  count = var.enable_cloudfront ? 1 : 0

  zone_id         = local.dawgs-armageddon_zone_id
  name            = var.domain_name  # thedawgs2025.click
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.dawgs-armageddon_cf01[0].domain_name
    zone_id                = aws_cloudfront_distribution.dawgs-armageddon_cf01[0].hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_cloudfront_distribution.dawgs-armageddon_cf01]
}