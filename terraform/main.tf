provider "aws" {
  region = "us-east-1"
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# S3 Bucket for Hosting Frontend
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "file-sharing-home-bucket"
  force_destroy = true

  tags = {
    Name = "Home File Sharing Bucket"
  }
}

# S3 Website Configuration
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Upload Static HTML to S3
resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "${path.module}/app/index.html"
  content_type = "text/html"
}

# EC2 Instance for Signaling Server
resource "aws_instance" "signaling_server" {
  ami                   = data.aws_ami.amazon_linux.id
  instance_type         = "t2.micro"
  key_name              = aws_key_pair.file_sharing_key.key_name
  vpc_security_group_ids = [aws_security_group.signaling_server_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              mkdir -p /app
              cd /app
              cat << 'EOM' > signaling_server.js
              const WebSocket = require("ws");

              const server = new WebSocket.Server({ port: 8080 });
              let connectedDevices = [];

              server.on("connection", (socket) => {
                  console.log("Device connected");

                  socket.on("message", (message) => {
                      const data = JSON.parse(message);
                      if (data.type === "register") {
                          connectedDevices.push({ id: data.id, name: data.name, socket });
                          broadcastDevices();
                      } else if (data.type === "disconnect") {
                          connectedDevices = connectedDevices.filter((d) => d.id !== data.id);
                          broadcastDevices();
                      } else {
                          connectedDevices.forEach((device) => {
                              if (device.id !== data.id) {
                                  device.socket.send(JSON.stringify(data));
                              }
                          });
                      }
                  });

                  socket.on("close", () => {
                      connectedDevices = connectedDevices.filter((d) => d.socket !== socket);
                      broadcastDevices();
                  });
              });

              function broadcastDevices() {
                  const deviceList = connectedDevices.map((device) => ({
                      id: device.id,
                      name: device.name,
                  }));
                  connectedDevices.forEach((device) => {
                      device.socket.send(JSON.stringify({ type: "deviceList", devices: deviceList }));
                  });
              }

              console.log("Signaling server running on ws://0.0.0.0:8080");
              EOM
              node signaling_server.js &
  EOF

  tags = {
    Name = "Signaling Server"
  }
}

# Security Group for Signaling Server
resource "aws_security_group" "signaling_server_sg" {
  name        = "signaling-server-sg"
  description = "Allow WebSocket traffic for signaling server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# Key Pair for EC2
resource "aws_key_pair" "file_sharing_key" {
  key_name   = "file-sharing-key"
  public_key = tls_private_key.key.public_key_openssh
}

# Generate SSH Key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 2048
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
