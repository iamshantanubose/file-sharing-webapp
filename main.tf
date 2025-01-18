provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-storage-shaan"
    key    = "file-sharing-app/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_vpc" "file_sharing_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "file-sharing-vpc"
  }
}

resource "aws_subnet" "file_sharing_subnet" {
  vpc_id            = aws_vpc.file_sharing_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "file-sharing-subnet"
  }
}

resource "aws_internet_gateway" "file_sharing_igw" {
  vpc_id = aws_vpc.file_sharing_vpc.id
  tags = {
    Name = "file-sharing-igw"
  }
}

resource "aws_route_table" "file_sharing_route_table" {
  vpc_id = aws_vpc.file_sharing_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.file_sharing_igw.id
  }
  tags = {
    Name = "file-sharing-route-table"
  }
}

resource "aws_route_table_association" "file_sharing_rta" {
  subnet_id      = aws_subnet.file_sharing_subnet.id
  route_table_id = aws_route_table.file_sharing_route_table.id
}

resource "aws_security_group" "file_sharing_sg" {
  vpc_id = aws_vpc.file_sharing_vpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "file-sharing-sg"
  }
}

# Declare the data source for the Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "file_sharing_instance" {
  ami                = data.aws_ami.amazon_linux.id
  instance_type      = "t2.micro"
  subnet_id          = aws_subnet.file_sharing_subnet.id
  security_group_ids = [aws_security_group.file_sharing_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              mkdir -p /app
              cd /app
              echo "export PORT=3000" >> /etc/environment
              echo "export NODE_ENV=production" >> /etc/environment
              echo "<html><body>Welcome to File Sharing App</body></html>" > /app/index.html
              cat << EOM > app.js
              const express = require('express');
              const app = express();
              app.get('/', (req, res) => res.sendFile('/app/index.html'));
              app.listen(3000);
              EOM
              node app.js
  EOF

  tags = {
    Name = "file-sharing-instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.file_sharing_instance.public_ip
}
