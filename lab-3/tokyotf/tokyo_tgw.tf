# # Explanation: Shinjuku Station is the hub — Tokyo is the data authority.
# resource "aws_ec2_transit_gateway" "shinjuku_tgw01" {
#   description = "shinjuku-tgw01 (Tokyo hub)"

#   tags = {
#     Name   = "shinjuku-tgw01"
#     Role   = "hub"
#     Region = "ap-northeast-1"
#   }
# }

# # Explanation: Shinjuku connects to the Tokyo VPC — this is the gate to the medical records vault.
# resource "aws_ec2_transit_gateway_vpc_attachment" "shinjuku_attach_tokyo_vpc01" {
#   transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
#   vpc_id             = aws_vpc.chewbacca_vpc01.id
#   subnet_ids         = [aws_subnet.chewbacca_private_subnet01.id, aws_subnet.chewbacca_private_subnet02.id]

#   tags = {
#     Name = "shinjuku-attach-tokyo-vpc01"
#   }
# }

# # Explanation: Shinjuku opens a corridor request to Liberdade.
# # The peer TGW ID comes from a variable — São Paulo is a separate Terraform state.
# # Workflow:
# #   1. Apply São Paulo state first → get liberdade_tgw_id output
# #   2. Pass that ID as var.saopaulo_tgw_id in Tokyo tfvars
# #   3. Apply Tokyo state → peering request is created
# #   4. Apply São Paulo state again → peering request is accepted
# resource "aws_ec2_transit_gateway_peering_attachment" "shinjuku_to_liberdade_peer01" {
#   transit_gateway_id      = aws_ec2_transit_gateway.shinjuku_tgw01.id
#   peer_region             = "sa-east-1"
#   peer_transit_gateway_id = var.saopaulo_tgw_id # from São Paulo outputs — never reference cross-state directly

#   tags = {
#     Name = "shinjuku-to-liberdade-peer01"
#   }
# }

# # Explanation: Tokyo return route — traffic from Tokyo RDS goes back to São Paulo via TGW.
# resource "aws_route" "shinjuku_to_sp_route01" {
#   route_table_id         = aws_route_table.chewbacca_private_rt01.id
#   destination_cidr_block = var.saopaulo_vpc_cidr
#   transit_gateway_id     = aws_ec2_transit_gateway.shinjuku_tgw01.id

#   depends_on = [aws_ec2_transit_gateway_vpc_attachment.shinjuku_attach_tokyo_vpc01]
# }

resource "aws_ec2_transit_gateway_route" "tokyo_to_saopaulo" {
  destination_cidr_block         = var.saopaulo_vpc_cidr
  transit_gateway_route_table_id = aws_ec2_transit_gateway.shinjuku_tgw01.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.shinjuku_to_liberdade_peer01.id
}