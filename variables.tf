variable "profile" {
  description = "AWS profile to use"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the network where resources will be deployed"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_cidr_block" {
  description = "Public CIDR block"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID to use for RDS and EC2 instances"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID to associate with instances"
  type        = string
}

variable "db_instance_identifier" {
  description = "The identifier for the RDS instance"
  type        = string
}

variable "db_instance_class" {
  description = "The instance class to use for the RDS instance"
  type        = string
}

variable "db_engine" {
  description = "The engine to use for the RDS instance"
  type        = string
}

variable "db_engine_version" {
  description = "The engine version for the RDS instance"
  type        = string
  default     = "14.5"
}

variable "db_username" {
  description = "The username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
}

variable "db_allocated_storage" {
  description = "The storage size for the RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_subnet_group_name" {
  description = "The name of the RDS subnet group"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use for the EC2 instance"
  type        = string
}

variable "lambda_exec_role_arn" {
  description = "The ARN of the Lambda execution role"
  type        = string
}

variable "nodejs_runtime" {
  description = "The runtime to use for the Lambda function"
  type        = string
}
