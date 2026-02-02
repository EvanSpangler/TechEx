# Disaster Recovery

This document outlines disaster recovery procedures for the Wiz Technical Exercise infrastructure.

## Overview

While this is a demo/educational environment, the disaster recovery procedures documented here reflect real-world practices and can serve as a learning reference.

## Recovery Objectives

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | 30 minutes | Time to restore service |
| **RPO** (Recovery Point Objective) | 24 hours | Acceptable data loss window |

> **Note:** For this demo environment, data loss is acceptable. In production, RPO should align with business requirements.

## Disaster Scenarios

### Scenario 1: Single Component Failure

**Impact:** One service unavailable
**Examples:** MongoDB VM failure, EKS node failure

**Recovery:**
```bash
# Identify failed component
make status

# For EC2 instance failure - Terraform will recreate
terraform -chdir=terraform taint 'module.mongodb-vm.aws_instance.mongodb'
terraform -chdir=terraform apply -var-file=environments/demo.tfvars

# For EKS node failure - autoscaling should replace
# Manual intervention:
aws eks update-nodegroup-config \
  --cluster-name wiz-exercise-eks \
  --nodegroup-name wiz-exercise-nodes \
  --scaling-config desiredSize=2
```

---

### Scenario 2: EKS Cluster Failure

**Impact:** Application unavailable
**Recovery Time:** ~20 minutes

**Recovery Steps:**

```bash
# 1. Verify cluster state
aws eks describe-cluster --name wiz-exercise-eks --query 'cluster.status'

# 2. If cluster is FAILED, recreate
terraform -chdir=terraform taint 'module.eks.aws_eks_cluster.main'
terraform -chdir=terraform apply -var-file=environments/demo.tfvars

# 3. Update kubeconfig
aws eks update-kubeconfig --name wiz-exercise-eks

# 4. Redeploy application
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

# 5. Verify
kubectl get pods -n tasky
curl http://<new-alb-dns>/health
```

---

### Scenario 3: MongoDB Data Loss

**Impact:** All user data lost
**Recovery Time:** ~15 minutes (restore from backup)

**Recovery Steps:**

```bash
# 1. Check if backups exist
aws s3 ls s3://wiz-exercise-backup-<suffix>/

# 2. Download latest backup
aws s3 cp s3://wiz-exercise-backup-<suffix>/backup-latest.gz /tmp/

# 3. SSH to MongoDB instance
make ssh-mongodb

# 4. Stop application (prevent writes during restore)
kubectl scale deployment/tasky --replicas=0 -n tasky

# 5. Restore backup
mongorestore --gzip --archive=/tmp/backup-latest.gz --drop

# 6. Restart application
kubectl scale deployment/tasky --replicas=2 -n tasky

# 7. Verify data
mongo -u admin -p '<password>' --authenticationDatabase admin
use tasky
db.todos.count()
```

---

### Scenario 4: AWS Region Failure

**Impact:** Complete environment unavailable
**Recovery Time:** ~45 minutes (in alternate region)

**Recovery Steps:**

```bash
# 1. Update Terraform for new region
export AWS_REGION=us-west-2
cd terraform

# 2. Update backend configuration for new state
# Edit backend.tf or use -backend-config

# 3. Deploy in new region
terraform init -reconfigure
terraform apply -var-file=environments/demo.tfvars

# 4. Update DNS (if applicable)
# Point to new ALB DNS

# 5. Restore data from cross-region backup (if configured)
aws s3 sync s3://wiz-exercise-backup-us-east-1/ s3://wiz-exercise-backup-us-west-2/
```

---

### Scenario 5: Terraform State Loss

**Impact:** Cannot manage infrastructure via Terraform
**Recovery Time:** ~60 minutes

**Recovery Steps:**

**Option A: Restore from S3 backend (if versioned)**
```bash
# 1. List state versions
aws s3api list-object-versions \
  --bucket wiz-exercise-tfstate \
  --prefix terraform.tfstate

# 2. Restore previous version
aws s3api get-object \
  --bucket wiz-exercise-tfstate \
  --key terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.restored

# 3. Upload restored state
aws s3 cp terraform.tfstate.restored s3://wiz-exercise-tfstate/terraform.tfstate
```

**Option B: Import existing resources**
```bash
# 1. Initialize fresh state
terraform init

# 2. Import each resource
terraform import module.vpc.aws_vpc.main vpc-xxxxxxxx
terraform import module.eks.aws_eks_cluster.main wiz-exercise-eks
# ... continue for all resources

# 3. Verify
terraform plan
# Should show no changes if import successful
```

**Option C: Recreate everything**
```bash
# 1. Manually terminate all resources in AWS Console
# Be careful to get everything

# 2. Fresh deployment
terraform init
terraform apply -var-file=environments/demo.tfvars
```

---

### Scenario 6: Security Breach - Full Compromise

**Impact:** All credentials potentially compromised
**Recovery Time:** ~60 minutes

**Recovery Steps:**

```bash
# 1. IMMEDIATE - Revoke all access
# Disable IAM user/role used by attacker
aws iam update-access-key --access-key-id <key> --status Inactive --user-name <user>

# 2. Rotate all credentials
# AWS IAM keys
aws iam create-access-key --user-name deployment-user
aws iam delete-access-key --access-key-id <old-key> --user-name deployment-user

# MongoDB passwords
# (See runbooks.md for procedure)

# JWT secret
export TF_VAR_jwt_secret="$(openssl rand -base64 32)"

# SSH keys
# (See runbooks.md for procedure)

# 3. Destroy compromised infrastructure
terraform destroy -var-file=environments/demo.tfvars

# 4. Audit CloudTrail for attacker actions
aws cloudtrail lookup-events \
  --start-time $(date -d '24 hours ago' -Iseconds) \
  --output json > incident-audit.json

# 5. Redeploy fresh environment
terraform apply -var-file=environments/demo.tfvars

# 6. Document incident for lessons learned
```

---

## Backup Strategy

### Current Backup Configuration

| Component | Backup Method | Frequency | Retention |
|-----------|---------------|-----------|-----------|
| MongoDB data | mongodump to S3 | Manual/On-demand | 30 days |
| Terraform state | S3 with versioning | On every apply | 90 days |
| Application code | Git repository | On every push | Indefinite |
| Configuration | Git repository | On every push | Indefinite |

### Manual MongoDB Backup

```bash
# 1. SSH to MongoDB instance
make ssh-mongodb

# 2. Create backup
mongodump --gzip --archive=/tmp/backup-$(date +%Y%m%d).gz

# 3. Upload to S3
aws s3 cp /tmp/backup-$(date +%Y%m%d).gz \
  s3://wiz-exercise-backup-<suffix>/backup-$(date +%Y%m%d).gz
```

### Automated Backup (Recommended)

Add to MongoDB instance user data:

```bash
#!/bin/bash
# /etc/cron.daily/mongodb-backup

BACKUP_FILE="/tmp/backup-$(date +%Y%m%d-%H%M%S).gz"
S3_BUCKET="wiz-exercise-backup-<suffix>"

# Create backup
mongodump --gzip --archive=$BACKUP_FILE

# Upload to S3
aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/

# Update latest pointer
aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/backup-latest.gz

# Cleanup local file
rm $BACKUP_FILE
```

---

## Recovery Testing

### Test Schedule

| Test Type | Frequency | Duration |
|-----------|-----------|----------|
| Backup restore | Monthly | 30 min |
| Single component recovery | Monthly | 15 min |
| Full environment recreation | Quarterly | 60 min |
| Tabletop exercise | Quarterly | 2 hours |

### Backup Restore Test Procedure

```bash
# 1. Create test environment
export TF_VAR_environment="dr-test"
terraform workspace new dr-test
terraform apply -var-file=environments/demo.tfvars

# 2. Restore backup to test environment
aws s3 cp s3://wiz-exercise-backup-<suffix>/backup-latest.gz /tmp/
# ... restore procedure ...

# 3. Verify data integrity
# Check record counts, sample data

# 4. Cleanup test environment
terraform destroy -var-file=environments/demo.tfvars
terraform workspace select default
terraform workspace delete dr-test
```

---

## Communication Plan

### Escalation Matrix

| Severity | Impact | Response Time | Notify |
|----------|--------|---------------|--------|
| Critical | Full outage | Immediate | Project owner |
| High | Major feature unavailable | 15 min | Project owner |
| Medium | Degraded performance | 1 hour | Team |
| Low | Minor issue | 24 hours | Document only |

### Status Communication

For this demo project, use:
- GitHub Issues for tracking
- README status badge for current state

---

## Recovery Checklist

### Pre-Recovery
- [ ] Identify scope of failure
- [ ] Notify stakeholders
- [ ] Gather credentials and access
- [ ] Review this document

### During Recovery
- [ ] Follow appropriate scenario runbook
- [ ] Document actions taken
- [ ] Test each component as restored
- [ ] Monitor for errors

### Post-Recovery
- [ ] Verify all services operational
- [ ] Run smoke tests
- [ ] Update documentation if procedures changed
- [ ] Conduct brief retrospective
- [ ] Update runbooks if needed

---

## Related Documentation

- [Operational Runbooks](runbooks.md)
- [Architecture Overview](../architecture/overview.md)
- [Troubleshooting](../troubleshooting/common-issues.md)
- [Infrastructure - S3](../infrastructure/s3.md)
