# ==============================
# Genearl outputs
# ==============================
output "aws_region" {
  value       = var.region
  description = "AWS Region"
}

# ==============================
# Outputs for EC2
# ==============================
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2_instance.public_ip
}

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

output "rds_engine_version" {
  description = "The RDS engine version"
  value       = module.rds.db_instance_engine_version_actual
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
  value       = "${module.api_gateway.api_endpoint}/default"
}

# ==============================
# Outputs for SNS
# ==============================
output "sns_alerts_topic_arn" {
  description = "The ARN of the SNS topic for alerts"
  value       = module.sns.topic_arn
}

# ==============================
# Outputs for SQS
# ==============================
output "sqs_queue_arn" {
  description = "The ARN of the SQS queue for LinkuyConnect"
  value       = module.sqs.queue_arn
}

output "sqs_queue_url" {
  description = "The URL of the SQS queue for LinkuyConnect"
  value       = module.sqs.queue_url
}
