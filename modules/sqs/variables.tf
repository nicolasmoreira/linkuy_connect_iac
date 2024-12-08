variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "sqs_visibility_timeout" {
  description = "Visibility timeout for the SQS queue"
  type        = number
}

variable "sqs_message_retention_seconds" {
  description = "Retention period for SQS messages (in seconds)"
  type        = number
}
