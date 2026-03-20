# Explanation: Outputs are your mission report—what got built and where to find it.
output "chewbacca_vpc_id" {
  value = aws_vpc.chewbacca_vpc01.id
}

output "chewbacca_public_subnet_ids" {
  value = aws_subnet.chewbacca_public_subnets[*].id
}

output "chewbacca_private_subnet_ids" {
  value = aws_subnet.chewbacca_private_subnets[*].id
}

# output "chewbacca_ec2_instance_id" {
#   value = aws_instance.chewbacca_ec201.id
# }

output "chewbacca_ec2_instance_id" {
  value = aws_instance.chewbacca_ec201_private_bonus.id
}

output "chewbacca_rds_endpoint" {
  value = aws_db_instance.chewbacca_rds01.address
}

output "chewbacca_sns_topic_arn" {
  value = aws_sns_topic.chewbacca_sns_topic01.arn
}

output "chewbacca_log_group_name" {
  value = aws_cloudwatch_log_group.chewbacca_log_group01.name
}

output "chewbacca_ec201_private_ip" {
  value = aws_instance.chewbacca_ec201_private_bonus.private_ip
}

# output "chewbacca_ec201_public_ip" {
#   value = "http://${aws_instance.chewbacca_ec201.public_ip}"
# }