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
    description = "PostgreSQL port"
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
    cidr_blocks = var.allowed_ips
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

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_ips
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

# ==============================
# IAM Policy for SQS Access
# ==============================
resource "aws_iam_policy" "data_processor_sqs_policy" {
  name        = "data_processor_sqs_policy"
  description = "Allows data_processor to send messages to the SQS queue ${var.sqs_queue_name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sqs:SendMessage",
        Resource = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.sqs_queue_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "data_processor_policy_attach" {
  role       = "data_processor"
  policy_arn = aws_iam_policy.data_processor_sqs_policy.arn
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

  environment_variables = {
    DB_USERNAME        = var.db_username
    DB_PASSWORD        = var.db_password
    DB_NAME            = var.db_name
    RDS_ENDPOINT       = module.rds.db_instance_endpoint
    RDS_ENGINE_VERSION = var.rds_engine_version
    SQS_QUEUE_URL      = module.sqs.queue_url
    ENVIRONMENT        = var.environment
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
# API Gateway Configuration
# ==============================
resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.api_execution_arn}/*"
}

module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "5.2.1"

  name               = "linkuyconnect-api"
  protocol_type      = "HTTP"
  create_domain_name = false

  routes = {
    "POST /activity" = {
      authorization_type = "NONE"
      #api_key_required   = true

      integration = {
        type                   = "AWS_PROXY"
        uri                    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.lambda.lambda_function_arn}/invocations"
        payload_format_version = "2.0"
      }
    }

    "GET /rest/{proxy+}" = {
      authorization_type = "NONE"
      integration = {
        type                   = "HTTP_PROXY"
        uri                    = "http://${module.ec2_instance.public_ip}/{proxy}"
        method                 = "GET"
        payload_format_version = "1.0"
        timeout_milliseconds   = 29000
      }
    }

    "POST /rest/{proxy+}" = {
      authorization_type = "NONE"
      integration = {
        type                   = "HTTP_PROXY"
        uri                    = "http://${module.ec2_instance.public_ip}/{proxy}"
        method                 = "POST"
        payload_format_version = "1.0"
        timeout_milliseconds   = 29000
      }
    }

    "PUT /rest/{proxy+}" = {
      authorization_type = "NONE"
      integration = {
        type                   = "HTTP_PROXY"
        uri                    = "http://${module.ec2_instance.public_ip}/{proxy}"
        method                 = "PUT"
        payload_format_version = "1.0"
        timeout_milliseconds   = 29000
      }
    }

    "DELETE /rest/{proxy+}" = {
      authorization_type = "NONE"
      integration = {
        type                   = "HTTP_PROXY"
        uri                    = "http://${module.ec2_instance.public_ip}/{proxy}"
        method                 = "DELETE"
        payload_format_version = "1.0"
        timeout_milliseconds   = 29000
      }
    }
  }

  cors_configuration = {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "X-API-Key", "Authorization"]
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
  key_name                    = var.key_name

  user_data = templatefile("${path.module}/install.sh", {
    DB_USERNAME           = var.db_username
    DB_PASSWORD           = var.db_password
    DB_NAME               = var.db_name
    RDS_ENDPOINT          = module.rds.db_instance_endpoint
    AWS_REGION            = var.region
    RDS_ENGINE_VERSION    = var.rds_engine_version
    SQS_QUEUE_URL         = module.sqs.queue_url
    EXPO_TOKEN            = var.expo_token
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
  })
}
