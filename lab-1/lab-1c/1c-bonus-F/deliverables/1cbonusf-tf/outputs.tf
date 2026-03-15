# Explanation: Outputs are your mission report—what got built and where to find it.
output "dawgs-armageddon_vpc_id" {
  value = aws_vpc.dawgs-armageddon_vpc01.id
}

output "dawgs-armageddon_public_subnet_ids" {
  value = aws_subnet.dawgs-armageddon_public_subnets[*].id
}

output "dawgs-armageddon_private_subnet_ids" {
  value = aws_subnet.dawgs-armageddon_private_subnets[*].id
}

output "dawgs-armageddon_ec2_instance_id" {
  value = aws_instance.dawgs-armageddon_ec201.id

}

output "dawgs-armageddon_ec2_private_instance_id" {
  value = aws_instance.dawgs-armageddon_ec201_private_bonus.id
}

output "dawgs-armageddon_rds_endpoint" {
  value = aws_db_instance.dawgs-armageddon_rds01.address
}

output "dawgs-armageddon_sns_topic_arn" {
  value = aws_sns_topic.dawgs-armageddon_sns_topic01.arn
}

output "dawgs-armageddon_log_group_name" {
  value = aws_cloudwatch_log_group.dawgs-armageddon_log_group01.name
}

output "dawgs-armageddon_alb_dns_name" {
  value = aws_lb.dawgs-armageddon_alb01.dns_name
}

output "dawgs-armageddon_target_group_arn" {
  value = aws_lb_target_group.dawgs-armageddon_tg01.arn
}

output "dawgs-armageddon_apex_url_https" {
  value = "https://${var.domain_name}"
}

output "lb_url" {
  value       = "http://${aws_lb.dawgs-armageddon_alb01.dns_name}"
  description = "Direct ALB URL (useful for testing before DNS)"
}

output "app_url_http" {
  value       = "http://${local.dawgs-armageddon_fqdn}"
  description = "HTTP URL for app (will redirect to HTTPS)"
}

output "app_url_https" {
  value       = "https://${local.dawgs-armageddon_fqdn}"
  description = "HTTPS URL for app (primary access point)"
}

output "base_domain" {
  value       = var.domain_name
  description = "Base domain name"
}

# Optional: Combined output for convenience
output "app_urls" {
  value = {
    alb_direct = "http://${aws_lb.dawgs-armageddon_alb01.dns_name}"
    http       = "http://${local.dawgs-armageddon_fqdn}"
    https      = "https://${local.dawgs-armageddon_fqdn}"
  }
  description = "All access URLs for the application"
}

# Explanation: Outputs are the mission coordinates — where to point your browser and your blasters.
# output "dawgs-armageddon_alb_dns_name" {
#   value = aws_lb.dawgs-armageddon_alb01.dns_name
# }

# output "dawgs-armageddon_app_fqdn" {
#   value = "${var.app_subdomain}.${var.domain_name}"
# }

# output "dawgs-armageddon_target_group_arn" {
#   value = aws_lb_target_group.dawgs-armageddon_tg01.arn
# }

output "dawgs-armageddon_acm_cert_arn" {
  value = aws_acm_certificate.dawgs-armageddon_acm_cert01.arn
}

output "dawgs-armageddon_waf_arn" {
  value = var.enable_waf_sampled_requests_only ? aws_wafv2_web_acl.dawgs-armageddon_waf01[0].arn : null
}

output "dawgs-armageddon_dashboard_name" {
  value = aws_cloudwatch_dashboard.dawgs-armageddon_dashboard01.dashboard_name
}

output "dawgs-armageddon_waf_log_destination" {
  value = var.waf_log_destination
}

output "dawgs-armageddon_waf_logs_s3_bucket" {
  value = var.waf_log_destination == "s3" ? aws_s3_bucket.dawgs-armageddon_waf_logs_bucket01[0].bucket : null
}

output "dawgs-armageddon_waf_firehose_name" {
  value = var.waf_log_destination == "firehose" ? aws_kinesis_firehose_delivery_stream.dawgs-armageddon_waf_firehose01[0].name : null
}
