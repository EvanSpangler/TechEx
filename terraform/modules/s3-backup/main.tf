# S3 Backup Module - Intentionally vulnerable configuration for Wiz exercise
# VULNERABILITIES BY DESIGN:
# - Public read and listing enabled
# - Public access block disabled

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "backup" {
  bucket        = "${var.environment}-mongodb-backups-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name        = "${var.environment}-mongodb-backups"
    Description = "INTENTIONALLY PUBLIC - Wiz exercise demonstration"
  })
}

# VULNERABILITY: Disable public access block
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Enable versioning (good practice, even for vulnerable bucket)
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# VULNERABILITY: Public bucket policy
resource "aws_s3_bucket_policy" "backup_public" {
  bucket = aws_s3_bucket.backup.id

  depends_on = [aws_s3_bucket_public_access_block.backup]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backup.arn,
          "${aws_s3_bucket.backup.arn}/*"
        ]
      }
    ]
  })
}

# Upload a README explaining the vulnerability
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.backup.id
  key          = "README.txt"
  content      = <<-EOT
    ===============================================
    WIZ TECHNICAL EXERCISE - INTENTIONALLY VULNERABLE
    ===============================================

    This S3 bucket is INTENTIONALLY configured with public
    read and listing access for demonstration purposes.

    VULNERABILITIES DEMONSTRATED:
    1. Public read access enabled
    2. Public listing enabled
    3. Contains MongoDB database backups

    In a real environment, this would be a critical finding:
    - Attackers could download database backups
    - Backups may contain sensitive data
    - Even encrypted backups could be brute-forced

    REMEDIATION:
    1. Enable S3 Block Public Access
    2. Use restrictive bucket policies
    3. Enable S3 access logging
    4. Use AWS KMS for encryption
    5. Implement lifecycle policies

    This bucket is part of the Wiz Technical Exercise.
    ===============================================
  EOT
  content_type = "text/plain"

  tags = var.tags
}
