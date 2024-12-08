resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg-"
  description = "Security Group for RDS"
  vpc_id      = var.vpc_id  

  ingress {
    description      = "Allow PostgreSQL access"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/24"]
  }

  egress {
    description      = "Allow all egress traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "timescaledb_pg" {
  name        = "linkuyconnect-rds-pg"
  family      = "postgres16"
  description = "Parameter group for TimescaleDB with shared_preload_libraries"
  
  parameter {
    name         = "shared_preload_libraries"
    value        = "timescaledb"
    apply_method = "immediate"
  }
}

resource "aws_db_subnet_group" "default" {
  name        = var.db_subnet_group_name
  description = "Subnet group for RDS"
  subnet_ids  = var.public_subnet_id
}

resource "aws_db_instance" "default" {
  identifier              = var.db_instance_identifier
  allocated_storage       = var.db_allocated_storage
  instance_class          = var.db_instance_class
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = aws_db_parameter_group.timescaledb_pg.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.default.name
  publicly_accessible     = false
  skip_final_snapshot     = true
}
