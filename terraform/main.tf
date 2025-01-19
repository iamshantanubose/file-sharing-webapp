provider "aws" {
  region = "us-east-1"
}

# Default VPC
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

# S3 Bucket for Hosting Frontend
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "file-sharing-home-bucket"
  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "error.html"
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

# Upload `index.html` to S3
resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "${path.module}/app/index.html"
  content_type = "text/html"
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

# EC2 Instance for Signaling Server
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
              const WebSocket = require("ws");

              const server = new WebSocket.Server({ port: 8080 });
              let connectedDevices = [];

              server.on("connection", (socket) => {
                  console.log("New device connected");

                  socket.on("message", (data) => {
                      const message = JSON.parse(data);
                      if (message.type === "register") {
                          connectedDevices.push({
                              id: message.id,
                              name: message.name,
                              address: socket._socket.remoteAddress,
                              socket: socket,
                          });
                          broadcastDeviceList();
                      }

                      if (message.type === "disconnect") {
                          connectedDevices = connectedDevices.filter((d) => d.id !== message.id);
                          broadcastDeviceList();
                      }
                  });

                  socket.on("close", () => {
                      connectedDevices = connectedDevices.filter((d) => d.socket !== socket);
                      broadcastDeviceList();
                  });
              });

              function broadcastDeviceList() {
                  const deviceList = connectedDevices.map((device) => ({
                      id: device.id,
                      name: device.name,
                      address: device.address,
                  }));
                  connectedDevices.forEach((device) => {
                      device.socket.send(JSON.stringify({ type: "deviceList", devices: deviceList }));
                  });
              }

              console.log("Signaling server is running on ws://0.0.0.0:8080");
              EOM
              node signaling_server.js &
  EOF

  tags = {
    Name = "File Sharing Signaling Server"
  }
}

# Security Group for EC2
resource "aws_security_group" "file_sharing_sg" {
  name        = "file-sharing-sg"
  description = "Allow HTTP and WebSocket access"
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
