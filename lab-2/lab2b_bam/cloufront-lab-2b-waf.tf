############################################
# Lab 2A - CloudFront WAF (CLOUDFRONT Scope)
#
# Purpose: WAFv2 Web ACL scoped to CLOUDFRONT.
#
# CRITICAL AWS CONSTRAINT: CloudFront WAF ACLs
# MUST be created in us-east-1 regardless of
# where your other resources live. This is not
# optional — AWS enforces it hard.
#
# Analogy: Think of it like filing galactic tax
# forms — they always go to the Senate on
# Coruscant, no matter where you actually are.
#
# This file uses a provider alias to target
# us-east-1 even if var.aws_region differs.
############################################

############################################
# Provider Alias: us-east-1 (CloudFront WAF)
############################################

# Explanation: CloudFront WAF lives in us-east-1 — full stop.
# We create an aliased provider so Terraform knows where to
# deploy this resource even if your main region is different.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

############################################
# WAFv2 Web ACL (CLOUDFRONT scope)
############################################

# Explanation: This is your edge shield generator — it fires
# BEFORE traffic even reaches your ALB. CloudFront-scoped WAF
# runs at AWS edge locations, not inside your VPC.
resource "aws_wafv2_web_acl" "dawgs-armageddon_cf_waf01" {
  count = var.enable_cloudfront && var.enable_cloudfront_waf ? 1 : 0

  provider = aws.us_east_1

  name  = "${var.project_name}-cf-waf01"
  scope = "CLOUDFRONT" # Must be CLOUDFRONT for distributions; REGIONAL for ALB.

  # Explanation: Default = ALLOW everything, then rules override to block.
  # This is the standard pattern — you add rules to block, not rules to allow.
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-cf-waf01"
    sampled_requests_enabled   = true
  }

  ############################################
  # Rule 1: AWS Common Rule Set
  # Explanation: These are pre-built Rebel intel reports — AWS maintains
  # signatures for the most common exploits so you don't have to.
  ############################################
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {} # none = enforce the rule's own BLOCK/COUNT decisions
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-cf-waf-common"
      sampled_requests_enabled   = true
    }
  }

  ############################################
  # Rule 2: Known Bad Inputs
  # Explanation: Log4Shell, Spring4Shell, SSRF attempts —
  # the Empire's latest playbook. AWS keeps this list current.
  ############################################
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-cf-waf-badinputs"
      sampled_requests_enabled   = true
    }
  }

  ############################################
  # Rule 3: IP Reputation List
  # Explanation: Threat intel — these IPs are already on the Empire's
  # most-wanted list. Block them before they knock on the door.
  ############################################
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-cf-waf-iprep"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${var.project_name}-cf-waf01"
    Lab  = "2A"
  }
}

############################################
# CloudWatch Log Group for CloudFront WAF
# (must also be in us-east-1)
############################################

# Explanation: WAF logs go to a dedicated log group.
# The name MUST start with "aws-waf-logs-" — AWS enforces this.
resource "aws_cloudwatch_log_group" "dawgs-armageddon_cf_waf_log_group01" {
  count = var.enable_cloudfront && var.enable_cloudfront_waf ? 1 : 0

  provider = aws.us_east_1

  name              = "aws-waf-logs-${var.project_name}-cf-webacl01"
  retention_in_days = var.waf_log_retention_days

  tags = {
    Name = "${var.project_name}-cf-waf-log-group01"
    Lab  = "2A"
  }
}

############################################
# WAF Logging Configuration
############################################

# Explanation: Wire the edge shield to the black box —
# every ALLOW and BLOCK at CloudFront is now recorded.
resource "aws_wafv2_web_acl_logging_configuration" "dawgs-armageddon_cf_waf_logging01" {
  count = var.enable_cloudfront && var.enable_cloudfront_waf ? 1 : 0

  provider = aws.us_east_1

  resource_arn = aws_wafv2_web_acl.dawgs-armageddon_cf_waf01[0].arn
  log_destination_configs = [
    aws_cloudwatch_log_group.dawgs-armageddon_cf_waf_log_group01[0].arn
  ]

  depends_on = [
    aws_wafv2_web_acl.dawgs-armageddon_cf_waf01,
    aws_cloudwatch_log_group.dawgs-armageddon_cf_waf_log_group01
  ]
}

