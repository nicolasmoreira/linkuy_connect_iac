resource "aws_sqs_queue" "linkuyconnect_activity" {
  name                        = var.sqs_queue_name
  visibility_timeout_seconds  = var.sqs_visibility_timeout
  message_retention_seconds   = var.sqs_message_retention_seconds
}
