# ==============================
# AWS Provider Configuration
# ==============================
variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID for EC2 instance"
  type        = string
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for EC2 instance"
  type        = string
  sensitive   = true
}

# ==============================
# RDS Configuration
# ==============================
variable "db_family" {
  description = "Database engine family for RDS (e.g., postgres16)"
  type        = string
}

variable "db_instance_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
}

variable "rds_engine" {
  description = "Engine for the RDS instance (e.g., postgres, mysql, etc.)"
  type        = string
}

variable "rds_engine_version" {
  description = "Version of the RDS engine"
  type        = string
}

variable "rds_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
}

variable "db_allocated_storage" {
  description = "The amount of storage (in GB) to allocate for the RDS instance"
  type        = number
}

variable "db_name" {
  description = "DB name"
  type        = string
}

variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_encryption_enabled" {
  description = "If true, enables encryption on the RDS instance"
  type        = bool
}

# ==============================
# Lambda Configuration
# ==============================
variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_handler" {
  description = "Handler of the Lambda function"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the ZIP file containing the Lambda function code"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function (e.g., nodejs22.x, python3.9)"
  type        = string
}

# ==============================
# SQS Configuration
# ==============================
variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "linkuyconnect-activity"
}

variable "sqs_message_retention_seconds" {
  description = "Time in seconds that SQS messages are kept before being deleted"
  type        = number
  default     = 86400
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for SQS messages in seconds"
  type        = number
  default     = 30
}

# ==============================
# EC2 Configuration
# ==============================
variable "ec2_instance_type" {
  description = "Type of EC2 instance (e.g., t4g.micro, t3.micro, etc.)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Name of .pem key"
  type        = string
}

# ==============================
# IPs Configuration
# ==============================
variable "allowed_ips" {
  description = "List of IP addresses allowed to access the EC2 via SSH and RDS via PostgreSQL port."
  type        = list(string)
}

# ==============================
# API Gateway Configuration
# ==============================
variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
}

# ==============================
# Others Configuration
# ==============================
variable "expo_token" {
  description = "Expo push token"
  type        = string
}