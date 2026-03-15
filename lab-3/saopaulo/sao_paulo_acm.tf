# --- Route 53 Record: São Paulo Latency Target ---
# resource "aws_route53_record" "origin_saopaulo" {
#   zone_id = data.aws_route53_zone.selected.zone_id

#   # This creates the "One Name, Two Destinations" setup.
#   name = "origin.${var.domain_name}"
#   type = "A"

#   # Unique ID for this specific path
#   set_identifier = "SaoPaulo-Latency-Target"

#   alias {
#     name                   =aws_lb.liberdade_alb01.dns_name # Pointing to SP ALB
#     zone_id                =aws_lb.liberdade_alb01.zone_id
#     evaluate_target_health = true
#   }

#   # Latency based routing = "Use this record if sa-east-1 is the fastest region"
#   latency_routing_policy {
#     region = "sa-east-1"
#   }
# }