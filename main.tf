# ==============================
# AWS Provider Configuration
# ==============================
provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "LinkuyConnect"
    }
  }
}

# ===== VPC =====
data "aws_vpc" "default" {
  default = true
}

# ===== Subnets =====
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ===== Security Groups =====
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg-linkuyconnect"
  description = "Security Group for RDS LinkuyConnect"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL port for TimescaleDB"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg-linkuyconnect"
  description = "Security Group for EC2 LinkuyConnect Worker"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ===== AWS Caller Identity =====
data "aws_caller_identity" "current" {}

# ===== RDS Configuration =====
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"

  identifier                  = var.db_instance_identifier
  family                      = var.db_family
  engine                      = var.rds_engine
  engine_version              = var.rds_engine_version
  instance_class              = var.rds_instance_class
  allocated_storage           = var.db_allocated_storage
  apply_immediately           = true
  username                    = var.db_username
  password                    = var.db_password
  db_name                     = var.db_name
  manage_master_user_password = false
  skip_final_snapshot         = true
  deletion_protection         = false
  subnet_ids                  = data.aws_subnets.default.ids
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  storage_encrypted           = var.db_encryption_enabled
  publicly_accessible         = true
}

# ===== Lambda Configuration =====
module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.16.0"

  function_name  = var.lambda_function_name
  handler        = var.lambda_handler
  runtime        = var.lambda_runtime
  source_path    = var.lambda_zip_path
  create_package = true
  publish        = true
  create_role    = true
  timeout        = 30

  environment_variables = {
    DB_HOST       = module.rds.db_instance_endpoint
    DB_NAME       = var.db_name
    DB_USER       = var.db_username
    DB_PASS       = var.db_password
    SQS_QUEUE_URL = module.sqs.queue_url
    ENVIRONMENT   = var.environment
  }

  policy_statements = {
    SQSAccess = {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = ["arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.sqs_queue_name}"]
    }
  }
}

# ==============================
# SQS Configuration
# ==============================
module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "4.2.1"

  name       = var.sqs_queue_name
  create     = true
  fifo_queue = false
}

# ==============================
# SNS Configuration
# ==============================
module "sns" {
  source  = "terraform-aws-modules/sns/aws"
  version = "6.1.2"

  name = var.sns_alerts_topic_name
}

resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = module.sns.topic_arn
  protocol  = "sqs"
  endpoint  = module.sqs.queue_arn
}

resource "aws_sns_topic_subscription" "http_subscription" {
  topic_arn = module.sns.topic_arn
  protocol  = "https"
  endpoint  = "https://${module.ec2_instance.public_ip}/worker/sqs"
}

# ==============================
# API Gateway Configuration
# ==============================
module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "5.2.1"

  name               = "linkuyconnect-api"
  protocol_type      = "HTTP"
  create_domain_name = false

  routes = {
    "POST /activity" = {
      authorization_type = "NONE"
      api_key_required   = true

      integration = {
        type                   = "AWS_PROXY"
        uri                    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.lambda.lambda_function_arn}/invocations"
        payload_format_version = "2.0"
      }
    }
  }

  cors_configuration = {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "X-API-Key"]
  }
}

# ==============================
# EC2 Configuration
# ==============================
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                   = "linkuyconnect-worker"
  instance_type          = var.ec2_instance_type
  ami                    = var.ami_id
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true
}
