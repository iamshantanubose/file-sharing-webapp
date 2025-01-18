output "s3_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.id
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.frontend_distribution.domain_name
}
