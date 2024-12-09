# ==============================
# Outputs for RDS
# ==============================
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

# ==============================
# Outputs for API Gateway
# ==============================
output "api_gateway_url" {
  description = "The API Gateway endpoint URL for LinkuyConnect"
  value       = module.api_gateway.api_endpoint
}
