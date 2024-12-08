# API Gateway URL
output "api_gateway_url" {
  description = "Base URL for API Gateway"
  value       = module.api_gateway.invoke_url
}

# RDS Endpoint
output "rds_endpoint" {
  description = "Endpoint for the RDS"
  value       = module.rds.rds_endpoint
}

# EC2 Worker Public IP
output "ec2_worker_public_ip" {
  description = "Public IP of the EC2 Worker"
  value       = module.ec2_worker.public_ip
}

# Kinesis Stream ARN
output "kinesis_stream_arn" {
  description = "ARN of Kinesis Stream"
  value       = module.kinesis.kinesis_arn
}

# Lambda ARN
output "lambda_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.lambda_arn
}
