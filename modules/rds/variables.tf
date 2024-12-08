variable "vpc_id" {
  description = "The VPC ID where the RDS instance will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "The public subnet ID where the RDS instance will be deployed"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "The name of the subnet group for the RDS instance"
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
  description = "The engine version to use for the RDS instance"
  type        = string
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
  description = "The amount of storage to allocate for the RDS instance in GB"
  type        = number
}

variable "security_group_id" {
  description = "The security group ID to associate with the RDS instance"
  type        = string
}
