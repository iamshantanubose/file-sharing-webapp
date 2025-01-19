output "s3_website_url" {
  value = aws_s3_bucket.frontend_bucket.website_endpoint
}

output "signaling_server_ip" {
  value = aws_instance.signaling_server.public_ip
}
