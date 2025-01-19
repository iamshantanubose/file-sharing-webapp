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

# S3 Bucket for Hosting Frontend
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "file-sharing-home-bucket"
  force_destroy = true

  tags = {
    Name = "Home File Sharing Bucket"
  }
}

# Configure Website Hosting
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Upload `index.html` to S3
resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "./app/index.html"
  content_type = "text/html"
}

# Ensure `index.html` Exists Dynamically
resource "null_resource" "create_index_html" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ./app && echo '<!DOCTYPE html><html><body><h1>Welcome to the File Sharing App</h1></body></html>' > ./app/index.html
    EOT
  }

  triggers = {
    index_html = "./app/index.html"
  }
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
}
