output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_bucket_name" {
  description = "CloudTrail S3 bucket name"
  value       = aws_s3_bucket.cloudtrail.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = one(aws_guardduty_detector.main[*].id)
}

output "securityhub_account_id" {
  description = "Security Hub account ID"
  value       = aws_securityhub_account.main.id
}

output "config_recorder_id" {
  description = "AWS Config recorder ID"
  value       = one(aws_config_configuration_recorder.main[*].id)
}

output "config_bucket_name" {
  description = "AWS Config S3 bucket name"
  value       = one(aws_s3_bucket.config[*].id)
}
