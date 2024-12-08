variable "vpc_id" {
  description = "The VPC ID to associate with the EC2 instance"
  type        = string
}

variable "subnet_id" {
  description = "The Subnet ID to associate with the EC2 instance"
  type        = string
}

variable "security_group_id" {
  description = "The Security Group ID to associate with the EC2 instance"
  type        = string
}

variable "ec2_instance_type" {
  description = "The instance type to use for EC2"
  type        = string
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use for the EC2 instance"
  type        = string
}

variable "sqs_queue_url" {
  description = "The URL of the SQS queue"
  type        = string
}