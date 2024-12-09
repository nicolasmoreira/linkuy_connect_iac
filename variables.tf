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

variable "db_parameter_group_name" {
  description = "Name of the RDS parameter group"
  type        = string
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
  description = "Runtime for the Lambda function (e.g., nodejs18.x, python3.9)"
  type        = string
}

# ==============================
# SQS Configuration
# ==============================
variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
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
