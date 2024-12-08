resource "aws_instance" "worker" {
  ami                    = var.ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    echo "export SQS_QUEUE_URL=${var.sqs_queue_url}" >> /etc/profile
    source /etc/profile
    amazon-linux-extras enable php8.3
    yum install -y php-cli php-mbstring php-xml php-pdo php-soap php-json
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
  EOT

  tags = {
    Name = "EC2 Worker"
  }
}
