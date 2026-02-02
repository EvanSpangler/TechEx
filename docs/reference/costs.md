# Cost Reference

This document provides a consolidated view of infrastructure costs for the Wiz Technical Exercise.

> **Important**: This is the single source of truth for cost estimates. Other documentation pages link here.

## Quick Summary

| Metric | Value |
|--------|-------|
| **Daily Cost** | ~$8-10/day |
| **Monthly Cost** | ~$250-300/month |
| **Hourly Cost** | ~$0.35-0.40/hour |

**Recommendation**: Destroy infrastructure when not in use with `make destroy`.

## Detailed Cost Breakdown

### Compute Resources

| Resource | Type | Hourly | Daily | Monthly |
|----------|------|--------|-------|---------|
| EKS Control Plane | Managed | $0.10 | $2.40 | $73.00 |
| EKS Node (t3.medium) | On-demand | $0.042 | $1.00 | $30.40 |
| MongoDB VM (t3.small) | On-demand | $0.021 | $0.50 | $15.20 |
| Wazuh VM (t3.medium) | On-demand | $0.042 | $1.00 | $30.40 |
| Red Team VM (t3.micro) | On-demand | $0.010 | $0.25 | $7.60 |
| **Compute Subtotal** | | $0.215 | $5.15 | $156.60 |

### Networking

| Resource | Type | Hourly | Daily | Monthly |
|----------|------|--------|-------|---------|
| NAT Gateway | Per hour | $0.045 | $1.08 | $32.85 |
| NAT Gateway Data | Per GB | Variable | ~$0.50 | ~$15.00 |
| ALB | Per hour | $0.023 | $0.55 | $16.43 |
| ALB LCU | Per LCU-hour | Variable | ~$0.20 | ~$6.00 |
| Data Transfer | Per GB out | Variable | ~$0.30 | ~$9.00 |
| **Networking Subtotal** | | ~$0.10 | ~$2.63 | ~$79.28 |

### Storage

| Resource | Type | Daily | Monthly |
|----------|------|-------|---------|
| EBS (MongoDB - 20GB gp3) | Per GB-month | $0.05 | $1.60 |
| EBS (Wazuh - 30GB gp3) | Per GB-month | $0.08 | $2.40 |
| EBS (Red Team - 8GB gp3) | Per GB-month | $0.02 | $0.64 |
| S3 Backup Bucket | Per GB-month | ~$0.01 | ~$0.30 |
| **Storage Subtotal** | | ~$0.16 | ~$4.94 |

### Security & Monitoring

| Resource | Type | Daily | Monthly |
|----------|------|-------|---------|
| CloudTrail | Free tier* | $0.00 | $0.00 |
| GuardDuty | Per analyzed event | ~$0.10 | ~$3.00 |
| Security Hub | Per check | ~$0.03 | ~$1.00 |
| VPC Flow Logs (CloudWatch) | Per GB ingested | ~$0.15 | ~$4.50 |
| **Security Subtotal** | | ~$0.28 | ~$8.50 |

*First trail in each region is free; data events incur charges.

### Total Estimated Costs

| Period | Low Estimate | High Estimate |
|--------|--------------|---------------|
| **Hourly** | $0.33 | $0.42 |
| **Daily** | $8.00 | $10.00 |
| **Weekly** | $56.00 | $70.00 |
| **Monthly** | $240.00 | $300.00 |

## Cost Optimization

### When Not In Use

Destroy all resources:
```bash
make destroy
```
**Savings**: 100% when destroyed

### Partial Optimization

If you need to keep some resources running:

```bash
# Stop EC2 instances (keep EBS)
aws ec2 stop-instances --instance-ids <mongodb-id> <wazuh-id> <redteam-id>

# Scale down EKS nodes
aws eks update-nodegroup-config \
  --cluster-name wiz-exercise-eks \
  --nodegroup-name wiz-exercise-nodes \
  --scaling-config minSize=0,maxSize=2,desiredSize=0
```
**Savings**: ~60% (still pay for EKS control plane, EBS, NAT Gateway)

### Use Spot Instances (Not Default)

For development/testing, EKS nodes could use Spot instances:
```hcl
# In terraform/modules/eks/main.tf
capacity_type = "SPOT"  # Instead of "ON_DEMAND"
```
**Savings**: ~60-70% on node costs

### Smaller Instance Types

For basic demos, smaller instances work:
```hcl
# In environments/demo.tfvars
eks_node_instance_type = "t3.small"   # Instead of t3.medium
mongodb_instance_type  = "t3.micro"   # Instead of t3.small
wazuh_instance_type    = "t3.small"   # Instead of t3.medium
```
**Savings**: ~30-40% on compute

## Cost Monitoring

### AWS Cost Explorer

1. Navigate to AWS Cost Explorer
2. Filter by tag: `project = wiz-exercise`
3. Group by: Service

### Budget Alert (Recommended)

Create a budget alert:
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "wiz-exercise-budget",
    "BudgetLimit": {"Amount": "300", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
      "TagKeyValue": ["user:project$wiz-exercise"]
    }
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{
      "SubscriptionType": "EMAIL",
      "Address": "your-email@example.com"
    }]
  }]'
```

### Quick Cost Check

```bash
# Get current month costs (requires Cost Explorer API access)
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{
    "Tags": {
      "Key": "project",
      "Values": ["wiz-exercise"]
    }
  }'
```

## Cost Comparison

### This Exercise vs Production

| Aspect | This Exercise | Production Equivalent |
|--------|---------------|----------------------|
| EKS Cluster | 1 small | Multiple, larger |
| Database | Single EC2 | RDS Multi-AZ or DocumentDB |
| Monitoring | Basic Wazuh | Full SIEM + APM |
| Redundancy | None | Multi-AZ, Multi-region |
| **Monthly Cost** | ~$250 | $2,000-10,000+ |

### Alternative Approaches

| Approach | Monthly Cost | Trade-offs |
|----------|--------------|------------|
| This exercise (full) | ~$250 | All features, all vulnerabilities |
| Minimal (fewer VMs) | ~$150 | Less monitoring capability |
| Local only (Minikube) | ~$0 | No cloud vulnerabilities |
| AWS Free Tier only | ~$50 | Limited to free tier resources |

## Billing FAQ

### Why is EKS so expensive?

EKS charges $0.10/hour for the control plane regardless of usage. This is ~$73/month just to have the cluster exist.

### Can I use Free Tier?

Some resources use Free Tier when available:
- t3.micro instances (750 hours/month for 12 months)
- S3 (5GB storage, 20,000 GET, 2,000 PUT)
- CloudTrail (first trail free)

### What if I forget to destroy?

Set up a budget alert (see above) to notify you at 80% of expected costs.

### Are there hidden costs?

Watch for:
- Data transfer costs (especially cross-AZ)
- CloudWatch Logs ingestion
- S3 request costs at scale
- NAT Gateway data processing

## Related Documentation

- [Architecture Overview](../architecture/overview.md)
- [Quick Start](../getting-started/quickstart.md)
- [Troubleshooting](../troubleshooting/common-issues.md)
