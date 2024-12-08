variable "lambda_exec_role_arn" {
  description = "The ARN of the IAM role to use for the Lambda function"
  type        = string
}

variable "nodejs_runtime" {
  description = "The runtime to use for the Lambda function"
  type        = string
}
