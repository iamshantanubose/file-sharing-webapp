output "s3_website_url" {
  value = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
}

output "ec2_public_ip" {
  value = aws_instance.signaling_server.public_ip
}
