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
data "aws_security_group" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ===== AWS Caller Identity =====
data "aws_caller_identity" "current" {}

# ==============================
# RDS Configuration
# ==============================
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"

  identifier             = var.db_instance_identifier
  family                 = var.db_family
  engine                 = var.rds_engine
  engine_version         = var.rds_engine_version
  instance_class         = var.rds_instance_class
  allocated_storage      = var.db_allocated_storage
  username               = var.db_username
  password               = var.db_password
  subnet_ids             = data.aws_subnets.default.ids
  vpc_security_group_ids = [data.aws_security_group.default.id]
  storage_encrypted      = var.db_encryption_enabled
  publicly_accessible    = false
}

# ===== RDS Parameter Group =====
resource "aws_db_parameter_group" "timescaledb" {
  name   = var.db_parameter_group_name
  family = var.db_family

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_cron"
    apply_method = "pending-reboot"
  }
}

# ==============================
# Lambda Configuration
# ==============================
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

  cloudwatch_logs_retention_in_days = 30

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
    RDSAccess = {
      effect    = "Allow"
      actions   = ["rds-db:connect"]
      resources = ["arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.rds.db_instance_endpoint}/*"]
    }
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.api_id}/*/*"
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

  tags = {
    Environment = var.environment
  }
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

    "$default" = {
      authorization_type = "NONE"

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

  tags = {
    Environment = var.environment
    Project     = "LinkuyConnect"
  }
}

resource "aws_api_gateway_api_key" "linkuyconnect_api_key" {
  name        = "linkuyconnect-api-key"
  enabled     = true
  description = "API Key for /activity route"
}

# ==============================
# EC2 Instance Configuration
# ==============================
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                   = "linkuyconnect-worker"
  instance_type          = var.ec2_instance_type
  ami                    = var.ami_id
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [data.aws_security_group.default.id]

  associate_public_ip_address = true

  tags = {
    Name = "linkuyconnect-worker"
  }
}
