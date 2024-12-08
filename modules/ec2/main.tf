resource "aws_instance" "worker" {
  ami                    = var.ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get upgrade -y
              EOF  

  tags = {
    Name = "EC2 Worker"
  }
}
