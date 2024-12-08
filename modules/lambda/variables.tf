variable "lambda_exec_role_arn" {
  description = "The ARN of the IAM role to use for the Lambda function"
  type        = string
}

variable "nodejs_runtime" {
  description = "The runtime to use for the Lambda function"
  type        = string
}

variable "sqs_queue_url" {
  description = "The URL of the SQS queue"
  type        = string
}

variable "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  type        = string
}
