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

data "aws_vpc" "default" {
  default = true
}

# Generate SSH Key Pair
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "file-sharing-key"
  public_key = tls_private_key.key_pair.public_key_openssh
}

# S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "file-sharing-home-bucket"
  force_destroy = true

  website {
    index_document = "index.html"
  }

  tags = {
    Name = "Home File Sharing Bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "disable_block" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "local_file" "index_html" {
  filename = "${path.module}/app/index.html"
  content  = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>File Sharing App</title>
    </head>
    <body>
      <h1>Welcome to the File Sharing App</h1>
    </body>
    </html>
  HTML
}

resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = local_file.index_html.filename
  content_type = "text/html"
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.disable_block]
}

# EC2 Instance for Backend
resource "aws_instance" "file_sharing_instance" {
  ami                   = data.aws_ami.amazon_linux.id
  instance_type         = "t2.micro"
  vpc_security_group_ids = [aws_security_group.file_sharing_sg.id]
  key_name              = aws_key_pair.ec2_key_pair.key_name

  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              mkdir -p /app
              cd /app
              echo "<html><body>Welcome to Home File Sharing App</body></html>" > /app/index.html
              cat << EOM > app.js
              const express = require('express');
              const app = express();
              const PORT = 3000;
              app.use(express.static('/app'));
              app.listen(PORT, () => console.log('App running on port', PORT));
              EOM
              node app.js &
  EOF
}

# Security Group for EC2
resource "aws_security_group" "file_sharing_sg" {
  name        = "file-sharing-sg"
  description = "Allow HTTP and SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

output "s3_website_url" {
  value = aws_s3_bucket_website_configuration.frontend_bucket.website_endpoint
}

output "ec2_public_ip" {
  value = aws_instance.file_sharing_instance.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.key_pair.private_key_pem
  sensitive = true
}
