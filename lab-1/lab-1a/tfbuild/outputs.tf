# Explanation: Outputs are your mission report—what got built and where to find it.
output "dawgs_armageddon_vpc_id" {
  value = aws_vpc.dawgs_armageddon_vpc01.id
}

output "dawgs_armageddon_public_subnet_ids" {
  value = aws_subnet.dawgs_armageddon_public_subnets[*].id
}

output "dawgs_armageddon_private_subnet_ids" {
  value = aws_subnet.dawgs_armageddon_private_subnets[*].id
}

output "dawgs_armageddon_ec2_instance_id" {
  value = aws_instance.dawgs_armageddon_ec201.id
}

output "dawgs_armageddon_rds_endpoint" {
  value = aws_db_instance.dawgs_armageddon_rds01.address
}

output "dawgs_armageddon_sns_topic_arn" {
  value = aws_sns_topic.dawgs_armageddon_sns_topic01.arn
}

output "dawgs_armageddon_log_group_name" {
  value = aws_cloudwatch_log_group.dawgs_armageddon_log_group01.name
}