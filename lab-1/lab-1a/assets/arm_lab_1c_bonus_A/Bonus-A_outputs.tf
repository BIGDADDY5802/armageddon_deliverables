# #Bonus-A outputs (append to outputs.tf)

# Explanation: These outputs prove Chewbacca built private hyperspace lanes (endpoints) instead of public chaos.
output "chewbacca_vpce_ssm_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_ssm01.id
}

output "chewbacca_vpce_logs_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_logs01.id
}

output "chewbacca_vpce_secrets_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_secrets01.id
}

output "chewbacca_vpce_s3_id" {
  value = aws_vpc_endpoint.chewbacca_vpce_s3_gw01.id
}

# output "chewbacca_private_ec2_instance_id_bonus" {
#   value = aws_instance.chewbacca_ec201_private_bonus.id
# }


