# # Add these to your existing Tokyo outputs.tf
# # São Paulo consumes these via variables (not remote state directly)

# output "tokyo_tgw_id" {
#   description = "Tokyo TGW ID — pass to São Paulo as var.saopaulo_tgw_id after first apply."
#   value       = aws_ec2_transit_gateway.shinjuku_tgw01.id
# }

# output "tokyo_tgw_peering_attachment_id" {
#   description = "Peering attachment ID — pass to São Paulo as var.tokyo_tgw_peering_attachment_id."
#   value       = aws_ec2_transit_gateway_peering_attachment.shinjuku_to_liberdade_peer01.id
# }

# output "tokyo_vpc_cidr" {
#   description = "Tokyo VPC CIDR — pass to São Paulo as var.tokyo_vpc_cidr."
#   value       = aws_vpc.chewbacca_vpc01.cidr_block
# }

# output "tokyo_rds_endpoint" {
#   description = "Tokyo RDS endpoint — pass to São Paulo as var.tokyo_rds_endpoint."
#   value       = aws_db_instance.dawgs-armageddon_rds01.address
# }
