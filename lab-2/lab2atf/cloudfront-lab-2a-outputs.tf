############################################
# Lab 2A - CloudFront Outputs
#
# Purpose: All outputs related to the Lab 2A
# CloudFront layer. These extend outputs.tf
# from Lab 1C without modifying it.
#
# After terraform apply, use these to:
#   - Verify the distribution domain
#   - Confirm WAF ARN is attached
#   - Get test commands to prove 403 lockdown
############################################

# ── Distribution Info ─────────────────────────────────────────────────────

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Use this to invalidate the cache: aws cloudfront create-invalidation --distribution-id <id> --paths '/*'"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.dawgs-armageddon_cf01[0].id : null
}

output "cloudfront_distribution_domain" {
  description = "CloudFront-assigned domain name (e.g. d1234abcd.cloudfront.net). This is what Route53 aliases to."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.dawgs-armageddon_cf01[0].domain_name : null
}

output "cloudfront_distribution_status" {
  description = "Deployment status of the distribution. 'Deployed' means edge locations are live. 'InProgress' means still propagating (~5-15 min)."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.dawgs-armageddon_cf01[0].status : null
}

output "cloudfront_distribution_arn" {
  description = "Full ARN of the CloudFront distribution."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.dawgs-armageddon_cf01[0].arn : null
}

# ── URLs ──────────────────────────────────────────────────────────────────

output "cloudfront_app_url" {
  description = "Primary app URL — routed through CloudFront. This is what users should use."
  value       = var.enable_cloudfront ? "https://${local.cf_fqdn}" : null
}

output "cloudfront_raw_domain_url" {
  description = "Direct CloudFront domain URL (bypasses Route53). Useful for testing before DNS propagates."
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.dawgs-armageddon_cf01[0].domain_name}" : null
}

output "alb_direct_url_for_403_test" {
  description = "Direct ALB URL for proving the 403 lockdown. After lab2a apply, curl -I this — you should get 403."
  value       = "https://${aws_lb.dawgs-armageddon_alb01.dns_name}"
}

# ── WAF ───────────────────────────────────────────────────────────────────

output "cloudfront_waf_acl_arn" {
  description = "ARN of the CloudFront-scoped WAFv2 Web ACL. Only populated when enable_cloudfront_waf=true."
  value       = var.enable_cloudfront && var.enable_cloudfront_waf ? aws_wafv2_web_acl.dawgs-armageddon_cf_waf01[0].arn : null
}

output "cloudfront_waf_log_group" {
  description = "CloudWatch log group receiving CloudFront WAF logs. Query with run_insights.sh."
  value       = var.enable_cloudfront && var.enable_cloudfront_waf ? aws_cloudwatch_log_group.dawgs-armageddon_cf_waf_log_group01[0].name : null
}

# ── Certificate ───────────────────────────────────────────────────────────

output "cloudfront_acm_cert_arn" {
  description = "ACM certificate ARN attached to CloudFront (us-east-1). Separate from the ALB cert."
  value       = var.enable_cloudfront ? aws_acm_certificate.dawgs-armageddon_cf_cert01[0].arn : null
}

# ── Origin Secret (redacted) ──────────────────────────────────────────────

output "cloudfront_origin_header_name" {
  description = "HTTP header name CloudFront injects into ALB requests. ALB listener rule checks this."
  value       = var.cloudfront_origin_header_name
}

output "cloudfront_origin_secret_hint" {
  description = "Reminder that the origin secret is set. Value is sensitive and not shown. Check var.cloudfront_origin_secret."
  value       = var.enable_cloudfront ? "(set — see var.cloudfront_origin_secret)" : null
  sensitive   = false
}

# ── Logging (optional) ────────────────────────────────────────────────────

output "cloudfront_logs_bucket" {
  description = "S3 bucket receiving CloudFront access logs. Null if enable_cloudfront_logging=false."
  value       = var.enable_cloudfront && var.enable_cloudfront_logging ? aws_s3_bucket.dawgs-armageddon_cf_logs_bucket01[0].bucket : null
}

# ── Test Commands ─────────────────────────────────────────────────────────
# Explanation: These outputs print the exact curl commands to run
# to prove the lab is working correctly.

# output "lab2a_test_commands" {
#   description = "Copy-paste curl commands to verify Lab 2A is working. Run these AFTER terraform apply completes and CF status is Deployed."
#   value = var.enable_cloudfront ? {
#     step1_should_be_403 = "curl -I https://${aws_lb.dawgs-armageddon_alb01.dns_name} --resolve ${aws_lb.dawgs-armageddon_alb01.dns_name}:443:$(dig +short ${aws_lb.dawgs-armageddon_alb01.dns_name} | head -1) 2>/dev/null | head -5"

#     step2_should_be_200_via_cloudfront = "curl -I https://${local.cf_fqdn}/list"

#     step3_prove_secret_works = "curl -I https://${aws_lb.dawgs-armageddon_alb01.dns_name}/list -H '${var.cloudfront_origin_header_name}: ${var.cloudfront_origin_secret}' -k"

#     note = "step1=403 (no secret, direct ALB) | step3=200 (correct secret) | step2=200 (via CloudFront) = Lab 2A PASS"
#   } : null
# }
