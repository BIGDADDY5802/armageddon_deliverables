############################################
# Bonus B - ALB (Public) -> Target Group (Private EC2) + TLS + WAF + Monitoring
############################################

locals {
  # Explanation: This is the roar address — where the galaxy finds your app.
  dawgs-armageddon_fqdn = "${var.app_subdomain}.${var.domain_name}"
}

############################################
# Security Group: ALB
############################################

# Explanation: The ALB SG is the blast shield — only allow what the Rebellion needs (80/443).
resource "aws_security_group" "dawgs-armageddon_alb_sg01" {
  name        = "${var.project_name}-alb-sg01"
  description = "ALB security group"
  vpc_id      = aws_vpc.dawgs-armageddon_vpc01.id

  # TODO: students add inbound 80/443 from 0.0.0.0/0
  # TODO: students set outbound to target group port (usually 80) to private targets

  tags = {
    Name = "${var.project_name}-alb-sg01"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dawgs-armageddon_alb_sg01_allow_http" {
  security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "dawgs-armageddon_alb_sg01_allow_https" {
  security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "dawgs-armageddon_alb_sg01_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Explanation: dawgs-armageddon only opens the hangar door — allow ALB -> EC2 on app port (e.g., 80).
resource "aws_security_group_rule" "dawgs-armageddon_ec2_ingress_from_alb01" {
  type                     = "ingress"
  security_group_id        = aws_security_group.dawgs-armageddon_ec2_sg01.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id

  # TODO: students ensure EC2 app listens on this port (or change to 8080, etc.)
}

############################################
# Wait for S3 bucket policy to propagate
############################################

# Explanation: AWS needs a moment to propagate S3 permissions—dawgs-armageddon waits patiently.
# resource "time_sleep" "wait_for_bucket_policy" {
#   count = var.enable_alb_access_logs ? 1 : 0

#   depends_on = [
#     aws_s3_bucket_policy.dawgs-armageddon_alb_logs_policy01
#   ]

#   create_duration = "60s"
# }

############################################
# Application Load Balancer
############################################

# Explanation: The ALB is your public customs checkpoint — it speaks TLS and forwards to private targets.
resource "aws_lb" "dawgs-armageddon_alb01" {
  name               = "${var.project_name}-alb01"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.dawgs-armageddon_alb_sg01.id]
  subnets         = aws_subnet.dawgs-armageddon_public_subnets[*].id

  access_logs {
    bucket  = aws_s3_bucket.dawgs-armageddon_alb_logs_bucket01[0].bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }

  tags = {
    Name = "${var.project_name}-alb01"
  }

  # depends_on = [
  #   time_sleep.wait_for_bucket_policy
  # ]
}


############################################
# Target Group + Attachment
############################################

# Explanation: Target groups are dawgs-armageddon’s “who do I forward to?” list — private EC2 lives here.
resource "aws_lb_target_group" "dawgs-armageddon_tg01" {
  name     = "${var.project_name}-tg01"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.dawgs-armageddon_vpc01.id

  # TODO: students set health check path to something real (e.g., /health)
  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg01"
  }
}

# Explanation: dawgs-armageddon personally introduces the ALB to the private EC2 — “this is my friend, don’t shoot.”
resource "aws_lb_target_group_attachment" "dawgs-armageddon_tg_attach01" {
  target_group_arn = aws_lb_target_group.dawgs-armageddon_tg01.arn
  target_id        = aws_instance.dawgs-armageddon_ec201_private_bonus.id # The PRIVATE instance
  port             = 80

  # TODO: students ensure EC2 security group allows inbound from ALB SG on this port (rule above)
}

############################################
# ACM Certificate (TLS) for app.dawgs-armageddon-growl.com
############################################

# Explanation: TLS is the diplomatic passport — browsers trust you, and dawgs-armageddon stops growling at plaintext.
# Note: When we change to app.thedawgs2025.click, we need to update the domain_name here too.
resource "aws_acm_certificate" "dawgs-armageddon_acm_cert01" {
  domain_name               = var.domain_name
  subject_alternative_names = [local.dawgs-armageddon_fqdn, "*.${var.domain_name}"]
  validation_method         = var.certificate_validation_method

  # TODO: students can add subject_alternative_names like var.domain_name if desired

  tags = {
    Name = "${var.project_name}-acm-cert01"
  }
}

# Explanation: DNS validation records are the “prove you own the planet” ritual — Route53 makes this elegant.
# TODO: students implement aws_route53_record(s) if they manage DNS in Route53.
resource "aws_route53_record" "dawgs-armageddon_acm_validation" {
  for_each = var.certificate_validation_method == "DNS" ? {
    for dvo in aws_acm_certificate.dawgs-armageddon_acm_cert01.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_hosted_zone_id

}
# Explanation: Once validated, ACM becomes the “green checkmark” — until then, ALB HTTPS won’t work.
resource "aws_acm_certificate_validation" "dawgs-armageddon_acm_validation01" {
  certificate_arn = aws_acm_certificate.dawgs-armageddon_acm_cert01.arn


  # TODO: if using DNS validation, students must pass validation_record_fqdns
  validation_record_fqdns = [for record in aws_route53_record.dawgs-armageddon_acm_validation : record.fqdn]

}

############################################
# ALB Listeners: HTTP -> HTTPS redirect, HTTPS -> TG
############################################

# Explanation: HTTP listener is the decoy airlock — it redirects everyone to the secure entrance.
resource "aws_lb_listener" "dawgs-armageddon_http_listener01" {
  load_balancer_arn = aws_lb.dawgs-armageddon_alb01.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Explanation: HTTPS listener is the real hangar bay — TLS terminates here, then traffic goes to private targets.
resource "aws_lb_listener" "dawgs-armageddon_https_listener01" {
  load_balancer_arn = aws_lb.dawgs-armageddon_alb01.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.dawgs-armageddon_acm_cert01.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dawgs-armageddon_tg01.arn
  }

  # depends_on = [aws_acm_certificate_validation.dawgs-armageddon_acm_validation01_dns_bonus]
}

############################################
# Route 53: app.thedawgs2025.click → ALB
############################################

resource "aws_route53_record" "dawgs-armageddon_app_alias" {
  zone_id = var.route53_hosted_zone_id
  name    = local.dawgs-armageddon_fqdn # "app.thedawgs2025.click"
  type    = "A"

  alias {
    name                   = aws_lb.dawgs-armageddon_alb01.dns_name
    zone_id                = aws_lb.dawgs-armageddon_alb01.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.dawgs-armageddon_alb01]
}


############################################
# WAFv2 Web ACL (Basic managed rules)
############################################

# Explanation: WAF is the shield generator — it blocks the cheap blaster fire before it hits your ALB.
resource "aws_wafv2_web_acl" "dawgs-armageddon_waf01" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project_name}-waf01"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf01"
    sampled_requests_enabled   = true
  }

  # Explanation: AWS managed rules are like hiring Rebel commandos — they’ve seen every trick.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${var.project_name}-waf01"
  }
}

# Explanation: Attach the shield generator to the customs checkpoint — ALB is now protected.
resource "aws_wafv2_web_acl_association" "dawgs-armageddon_waf_assoc01" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.dawgs-armageddon_alb01.arn
  web_acl_arn  = aws_wafv2_web_acl.dawgs-armageddon_waf01[0].arn
}

############################################
# CloudWatch Alarm: ALB 5xx -> SNS
############################################

# Explanation: When the ALB starts throwing 5xx, that’s the Falcon coughing — page the on-call Wookiee.
resource "aws_cloudwatch_metric_alarm" "dawgs-armageddon_alb_5xx_alarm01" {
  alarm_name          = "${var.project_name}-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.dawgs-armageddon_alb01.arn_suffix
  }

  alarm_actions = [aws_sns_topic.dawgs-armageddon_sns_topic01.arn]

  tags = {
    Name = "${var.project_name}-alb-5xx-alarm01"
  }
}

############################################
# CloudWatch Dashboard (Skeleton)
############################################

# Explanation: Dashboards are your cockpit HUD — dawgs-armageddon wants dials, not vibes.
resource "aws_cloudwatch_dashboard" "dawgs-armageddon_dashboard01" {
  dashboard_name = "${var.project_name}-dashboard01"

  # TODO: students can expand widgets; this is a minimal workable skeleton
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.dawgs-armageddon_alb01.arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", aws_lb.dawgs-armageddon_alb01.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "dawgs-armageddon ALB: Requests + 5XX"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.dawgs-armageddon_alb01.arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "dawgs-armageddon ALB: Target Response Time"
        }
      }
    ]
  })
}
