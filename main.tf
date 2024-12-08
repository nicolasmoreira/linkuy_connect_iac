module "networking" {
  source = "./modules/networking"
  vpc_cidr_block            = var.vpc_cidr_block
  public_cidr_block         = var.public_cidr_block  
}

module "iam" {
  source = "./modules/iam"
}

module "rds" {
  source                    = "./modules/rds"
  vpc_id                    = var.vpc_id
  public_subnet_id          = [var.public_subnet_id]
  db_instance_identifier    = var.db_instance_identifier
  db_instance_class         = var.db_instance_class
  db_engine                 = var.db_engine
  db_engine_version         = var.db_engine_version
  db_username               = var.db_username
  db_password               = var.db_password
  db_allocated_storage      = var.db_allocated_storage
  security_group_id         = var.security_group_id
  db_subnet_group_name      = var.db_subnet_group_name
}

module "kinesis" {
  source = "./modules/kinesis"
  lambda_exec_role_arn = module.iam.lambda_exec_role_arn
}

module "lambda" {
  source     = "./modules/lambda"
  lambda_exec_role_arn = module.iam.lambda_exec_role_arn
  nodejs_runtime      = var.nodejs_runtime
}

module "api_gateway" {
  source = "./modules/api_gateway"
}

module "ec2_worker" {
  source            = "./modules/ec2"
  vpc_id            = var.vpc_id
  subnet_id         = var.public_subnet_id
  security_group_id = var.security_group_id
  ec2_instance_type = var.ec2_instance_type
  ami_id            = var.ami_id
}
