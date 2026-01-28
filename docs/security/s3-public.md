# WIZ-001: Public S3 Bucket

## Overview

| Attribute | Value |
|-----------|-------|
| **ID** | WIZ-001 |
| **Severity** | Critical |
| **CVSS** | 9.8 |
| **Component** | S3 Backup Bucket |
| **MITRE ATT&CK** | T1530 - Data from Cloud Storage |

## Description

The S3 bucket used for MongoDB backups is configured with public read access, allowing anyone on the internet to list and download backup files without authentication.

## Vulnerable Configuration

```hcl
# terraform/modules/s3-backup/main.tf

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = false  # VULNERABLE
  block_public_policy     = false  # VULNERABLE
  ignore_public_acls      = false  # VULNERABLE
  restrict_public_buckets = false  # VULNERABLE
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadAccess"
        Effect    = "Allow"
        Principal = "*"  # VULNERABLE: Anyone
        Action    = [
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
```

## Exploitation

### Prerequisites
- None (unauthenticated access)

### Steps

1. **Discover bucket name** (via reconnaissance or this exercise)

2. **List bucket contents**
   ```bash
   aws s3 ls s3://wiz-exercise-backups-xxxxx --no-sign-request
   ```

3. **Download backup files**
   ```bash
   aws s3 cp s3://wiz-exercise-backups-xxxxx/backups/mongodb-backup-20240115.tar.gz . --no-sign-request
   ```

4. **Extract and analyze**
   ```bash
   tar -xzf mongodb-backup-20240115.tar.gz
   # Backups contain full database dump including credentials
   ```

### Demo

```bash
make demo-s3
```

Output:
```
[VULNERABILITY] S3 bucket publicly accessible

Listing bucket without authentication:
aws s3 ls s3://wiz-exercise-backups-abc123 --no-sign-request
2024-01-15 02:00:00     15728640 mongodb-backup-20240115.tar.gz
2024-01-14 02:00:00     15695872 mongodb-backup-20240114.tar.gz
```

## Impact

### Data at Risk
- Complete MongoDB database dumps
- Application data (user todos)
- Potentially credentials if stored in DB
- Database schema information

### Business Impact
- **Confidentiality**: Complete loss of backup data confidentiality
- **Compliance**: GDPR, PCI-DSS, SOC 2 violations
- **Reputation**: Data breach notification requirements

## Detection

### AWS GuardDuty

Finding type: `Policy:S3/BucketPublicAccessGranted`

```json
{
  "type": "Policy:S3/BucketPublicAccessGranted",
  "severity": 5,
  "resource": {
    "type": "S3Bucket",
    "s3BucketDetails": [{
      "name": "wiz-exercise-backups-xxxxx",
      "publicAccess": {
        "effectivePermission": "PUBLIC"
      }
    }]
  }
}
```

### AWS Security Hub

Finding: `S3.2 - S3 buckets should prohibit public read access`

### CloudTrail

Look for `GetObject` and `ListBucket` events without authentication:

```json
{
  "eventName": "GetObject",
  "userIdentity": {
    "type": "AWSAccount",
    "accountId": "ANONYMOUS"
  },
  "requestParameters": {
    "bucketName": "wiz-exercise-backups-xxxxx"
  }
}
```

### Detection Query (CloudWatch Logs Insights)

```sql
fields @timestamp, eventName, userIdentity.type, requestParameters.bucketName
| filter eventSource = 's3.amazonaws.com'
| filter userIdentity.type = 'AWSAccount' OR userIdentity.accountId = 'ANONYMOUS'
| sort @timestamp desc
```

## Remediation

### Immediate Fix

Enable S3 Block Public Access:

```hcl
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Account-Level Protection

Enable for entire AWS account:

```bash
aws s3control put-public-access-block \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Best Practices

1. **Enable encryption**
   ```hcl
   resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
     bucket = aws_s3_bucket.backup.id

     rule {
       apply_server_side_encryption_by_default {
         sse_algorithm     = "aws:kms"
         kms_master_key_id = aws_kms_key.backup.arn
       }
     }
   }
   ```

2. **Enable versioning**
   ```hcl
   resource "aws_s3_bucket_versioning" "backup" {
     bucket = aws_s3_bucket.backup.id
     versioning_configuration {
       status = "Enabled"
     }
   }
   ```

3. **Enable access logging**
   ```hcl
   resource "aws_s3_bucket_logging" "backup" {
     bucket = aws_s3_bucket.backup.id

     target_bucket = aws_s3_bucket.logs.id
     target_prefix = "backup-access-logs/"
   }
   ```

4. **Restrict to VPC endpoint**
   ```hcl
   resource "aws_s3_bucket_policy" "backup" {
     bucket = aws_s3_bucket.backup.id

     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [
         {
           Effect    = "Deny"
           Principal = "*"
           Action    = "s3:*"
           Resource  = [
             aws_s3_bucket.backup.arn,
             "${aws_s3_bucket.backup.arn}/*"
           ]
           Condition = {
             StringNotEquals = {
               "aws:sourceVpce" = aws_vpc_endpoint.s3.id
             }
           }
         }
       ]
     })
   }
   ```

## References

- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Block Public Access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [MITRE ATT&CK T1530](https://attack.mitre.org/techniques/T1530/)
- [CIS AWS Benchmark 2.1.1](https://www.cisecurity.org/benchmark/amazon_web_services)
