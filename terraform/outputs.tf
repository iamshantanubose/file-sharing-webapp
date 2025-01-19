output "s3_website_url" {
  value = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
}

output "ec2_public_ip" {
  value = aws_instance.file_sharing_instance.public_ip
}
