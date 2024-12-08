# ==============================
# Outputs for RDS
# ==============================

output "rds_parameter_group_name" {
  description = "The name of the RDS parameter group for TimescaleDB"
  value       = aws_db_parameter_group.timescaledb.name
}

output "rds_endpoint" {
  description = "The endpoint (hostname) for the RDS database instance"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "rds_instance_identifier" {
  description = "The identifier (ID) of the RDS instance"
  value       = module.rds.db_instance_identifier
}

# ==============================
# Outputs for Lambda
# ==============================

output "lambda_arn" {
  description = "The ARN of the AWS Lambda function for LinkuyConnect"
  value       = module.lambda.lambda_function_arn
}

output "lambda_name" {
  description = "The name of the AWS Lambda function for LinkuyConnect"
  value       = module.lambda.lambda_function_name
}

output "lambda_invoke_arn" {
  description = "The invoke ARN of the AWS Lambda function for LinkuyConnect"
  value       = module.lambda.lambda_function_invoke_arn
}

# ==============================
# Outputs for API Gateway
# ==============================

output "api_gateway_url" {
  description = "The API Gateway endpoint URL for LinkuyConnect"
  value       = module.api_gateway.api_endpoint
}
