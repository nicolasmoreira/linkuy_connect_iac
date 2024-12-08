output "vpc_id" {
  description = "The VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "The ID of the security group for RDS"
  value       = aws_security_group.default.id
}

