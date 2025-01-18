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

# Default VPC
data "aws_vpc" "default" {
  default = true
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

# Disable Public Access Restrictions
resource "aws_s3_bucket_public_access_block" "disable_block" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Policy for Public Access
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

# Upload `index.html` to S3
resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "${path.module}/app/index.html"
  content_type = "text/html"
}

# EC2 Instance for Backend (Signaling Server)
resource "aws_instance" "file_sharing_instance" {
  ami                   = data.aws_ami.amazon_linux.id
  instance_type         = "t2.micro"
  key_name              = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.file_sharing_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              mkdir -p /app
              cd /app
              cat << EOM > signaling_server.js
              const WebSocket = require('ws');
              const wss = new WebSocket.Server({ port: 8080 });
              console.log('WebSocket signaling server running on ws://0.0.0.0:8080');

              wss.on('connection', (ws) => {
                ws.on('message', (message) => {
                  console.log('Received:', message);
                  // Broadcast the message to all connected clients
                  wss.clients.forEach((client) => {
                    if (client !== ws && client.readyState === WebSocket.OPEN) {
                      client.send(message);
                    }
                  });
                });
              });
              EOM
              node signaling_server.js &
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
    from_port   = 8080
    to_port     = 8080
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

# Dynamic Amazon Linux AMI Lookup
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

output "s3_website_url" {
  value = aws_s3_bucket.frontend_bucket.website_endpoint
}

output "ec2_public_ip" {
  value = aws_instance.file_sharing_instance.public_ip
}
