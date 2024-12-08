resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "linkuyconnect-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_cidr_block
  map_public_ip_on_launch = true
  tags = {
    Name = "linkuyconnect-public-subnet"
  }
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "linkuyconnect-security-group"
  }
}

resource "aws_security_group_rule" "allow_all_inbound" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}
