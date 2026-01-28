# AWS Issues

Troubleshooting AWS-specific problems.

## Credentials

### Error: No valid credential sources

```bash
# Check credentials are set
echo $AWS_ACCESS_KEY_ID

# Verify access
aws sts get-caller-identity
```

### Error: Access Denied

Check IAM permissions. See [Prerequisites](../getting-started/prerequisites.md).

## Quotas

### VPC Limit Exceeded

```bash
# Check current VPCs
aws ec2 describe-vpcs

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10
```

### EC2 Instance Limit

```bash
# Check vCPU quota
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

## EKS Issues

### Cluster Not Ready

EKS clusters take 15-20 minutes to create.

```bash
# Check status
aws eks describe-cluster --name wiz-exercise-eks --query 'cluster.status'
```

## GuardDuty

### Findings Not Appearing

1. Ensure GuardDuty is enabled
2. Wait 15-30 minutes for findings
3. Check detector status

```bash
aws guardduty list-detectors
```
