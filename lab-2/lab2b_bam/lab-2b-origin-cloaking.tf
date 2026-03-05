# Explanation: dawgs-armageddon only opens the hangar to CloudFront — everyone else gets the Wookiee roar.
data "aws_ec2_managed_prefix_list" "dawgs-armageddon_cf_origin_facing01" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Explanation: Only CloudFront origin-facing IPs may speak to the ALB — direct-to-ALB attacks die here.
resource "aws_security_group_rule" "dawgs-armageddon_alb_ingress_cf44301" {
  type              = "ingress"
  security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids = [
    data.aws_ec2_managed_prefix_list.dawgs-armageddon_cf_origin_facing01.id
  ]
}

# FIX: Allow 0.0.0.0/0 on 443 so direct hits reach the ALB listener.
# Without this rule, the SG drops the connection before the ALB sees it,
# producing a timeout instead of the 403 the directive requires.
#
# Defense-in-depth is preserved:
#   Layer 1 (this rule) — connection allowed through to ALB
#   Layer 2 (listener priority 10) — forward only if X-Origin-Verify header matches
#   Layer 3 (listener priority 99) — fixed-response 403 for everything else
#
# The prefix list rule above still limits CloudFront-sourced traffic to
# verified CloudFront IPs. This open rule handles the verification path —
# a direct curl hits the ALB, gets no X-Origin-Verify header, falls through
# to priority 99, and receives 403 "Forbidden" as the directive specifies.
resource "aws_security_group_rule" "dawgs-armageddon_alb_ingress_direct44301" {
  type              = "ingress"
  security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Explanation: This is dawgs-armageddon's secret handshake — if the header isn't present, you don't get in.
resource "random_password" "dawgs-armageddon_origin_header_value01" {
  length  = 32
  special = false
}

# Explanation: ALB checks for dawgs-armageddon's secret growl — no growl, no service.
resource "aws_lb_listener_rule" "dawgs-armageddon_require_origin_header01" {
  listener_arn = aws_lb_listener.dawgs-armageddon_https_listener01.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dawgs-armageddon_tg01.arn
  }
  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.dawgs-armageddon_origin_header_value01.result]
    }
  }
}

# Explanation: If you don't know the growl, you get a 403 — dawgs-armageddon does not negotiate.
resource "aws_lb_listener_rule" "dawgs-armageddon_default_block01" {
  listener_arn = aws_lb_listener.dawgs-armageddon_https_listener01.arn
  priority     = 99
  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
  condition {
    path_pattern { values = ["*"] }
  }
}
