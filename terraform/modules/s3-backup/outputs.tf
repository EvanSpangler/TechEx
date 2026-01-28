output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.backup.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.backup.arn
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.backup.bucket
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.backup.bucket_regional_domain_name
}
