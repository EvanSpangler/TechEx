# Operational Runbooks

This document provides step-by-step procedures for common operational tasks and incident response scenarios.

## Overview

These runbooks are designed for operators managing the Wiz Technical Exercise infrastructure. While this is a demo environment, the procedures reflect real-world operational practices.

## Table of Contents

- [Deployment Operations](#deployment-operations)
- [Monitoring & Alerting](#monitoring--alerting)
- [Incident Response](#incident-response)
- [Maintenance Tasks](#maintenance-tasks)
- [Disaster Recovery](#disaster-recovery)

---

## Deployment Operations

### Deploy Full Infrastructure

**When:** Initial setup or full recreation

**Prerequisites:**
- AWS credentials configured
- Required environment variables set
- GitHub secrets configured (for CI/CD)

**Steps:**

```bash
# 1. Clone and configure
git clone https://github.com/EvanSpangler/TechEx.git
cd TechEx/project

# 2. Set environment variables
export TF_VAR_mongodb_admin_pass="<secure-password>"
export TF_VAR_mongodb_app_pass="<secure-password>"
export TF_VAR_backup_encryption_key="<32-char-key>"

# 3. Bootstrap backend (first time only)
make bootstrap

# 4. Deploy infrastructure
make build
# or locally:
make deploy-local

# 5. Verify deployment
make status
make show
```

**Verification:**
- [ ] All Terraform resources created successfully
- [ ] EKS cluster accessible: `kubectl cluster-info`
- [ ] Application health: `curl http://<alb-dns>/health`
- [ ] MongoDB accessible via SSH tunnel

---

### Deploy Application Update

**When:** New application version needs deployment

**Steps:**

```bash
# 1. Build new container image
cd project/app
docker build -t tasky:new .

# 2. Run security scan
trivy image tasky:new

# 3. Push to ECR (via CI/CD or manually)
aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker tag tasky:new <account>.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-tasky:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-tasky:latest

# 4. Update Kubernetes deployment
kubectl set image deployment/tasky tasky=<new-image> -n tasky
kubectl rollout status deployment/tasky -n tasky
```

**Rollback if needed:**
```bash
kubectl rollout undo deployment/tasky -n tasky
```

---

### Destroy Infrastructure

**When:** Demo complete, cost management, or recreation needed

**Steps:**

```bash
# 1. Confirm no critical data exists
kubectl get pvc -A  # Check for persistent volumes
aws s3 ls s3://wiz-exercise-backup-*  # Check backup contents

# 2. Destroy via Makefile
make destroy

# 3. Verify destruction
aws ec2 describe-instances --filters "Name=tag:project,Values=wiz-exercise"
aws eks list-clusters
aws s3 ls | grep wiz-exercise
```

**Force destroy if stuck:**
```bash
make force-destroy
```

---

## Monitoring & Alerting

### Check System Health

**When:** Regular health check or suspected issue

**Steps:**

```bash
# 1. Check all pod status
kubectl get pods -A

# 2. Check application health
curl http://<alb-dns>/health

# 3. Check MongoDB
make ssh-mongodb
systemctl status mongod
mongo --eval "db.adminCommand('ping')"

# 4. Check Wazuh
make ssh-wazuh
docker-compose ps
curl -k https://localhost:443  # Wazuh dashboard

# 5. View recent logs
kubectl logs -n tasky deployment/tasky --tail=100
```

---

### Access Wazuh Dashboard

**When:** Security monitoring, alert review

**Steps:**

```bash
# 1. Get Wazuh instance IP
make ssh-info | grep wazuh

# 2. SSH tunnel for dashboard access
ssh -i keys/wazuh.pem -L 8443:localhost:443 ubuntu@<wazuh-ip>

# 3. Access dashboard
# Browser: https://localhost:8443
# Default credentials: admin / SecretPassword (change after first login)

# 4. Navigate to:
# - Security events: Modules > Security Events
# - Vulnerability detection: Modules > Vulnerability Detection
# - Agent status: Agents > list
```

---

### View CloudTrail Logs

**When:** Investigating API activity

**Steps:**

```bash
# 1. Via AWS Console
# CloudTrail > Event history
# Filter by: Event source, User name, Resource name

# 2. Via CLI
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject \
  --start-time $(date -d '1 hour ago' -Iseconds) \
  --output table

# 3. For S3 data events (if enabled)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::S3::Object
```

---

## Incident Response

### Suspected Compromise - MongoDB VM

**Indicators:**
- Unauthorized SSH logins
- Unusual process activity
- GuardDuty alerts
- Wazuh alerts for brute force

**Response Steps:**

```bash
# 1. ASSESS - Do not SSH yet, gather info
aws ec2 describe-instances --instance-ids <instance-id>
# Check: State, SecurityGroups, IamInstanceProfile

# 2. CONTAIN - Isolate the instance
aws ec2 modify-instance-attribute \
  --instance-id <instance-id> \
  --groups <isolated-security-group-id>  # SG with no ingress

# 3. PRESERVE - Create forensic snapshot
aws ec2 create-snapshot \
  --volume-id <volume-id> \
  --description "Forensic snapshot - incident $(date +%Y%m%d)"

# 4. INVESTIGATE - Analyze via SSM if available
aws ssm start-session --target <instance-id>
# Or attach to isolated forensic instance

# 5. Review logs
cat /var/log/auth.log
cat /var/log/mongodb/mongod.log
last -100

# 6. RECOVER - Replace instance
terraform taint module.mongodb-vm.aws_instance.mongodb
terraform apply -var-file=environments/demo.tfvars
```

---

### Suspected Compromise - Kubernetes

**Indicators:**
- Unauthorized pods
- Secret access alerts
- Unusual API calls
- GuardDuty EKS findings

**Response Steps:**

```bash
# 1. ASSESS - Review current state
kubectl get pods -A
kubectl get secrets -A
kubectl get events -A --sort-by='.lastTimestamp'

# 2. Check for suspicious pods
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# 3. Review RBAC bindings
kubectl get clusterrolebindings -o wide
kubectl get rolebindings -A -o wide

# 4. Check audit logs (if enabled)
kubectl logs -n kube-system -l k8s-app=kube-apiserver --tail=500

# 5. CONTAIN - Delete suspicious resources
kubectl delete pod <suspicious-pod> -n <namespace>

# 6. Rotate secrets
kubectl delete secret mongodb-credentials -n tasky
kubectl create secret generic mongodb-credentials \
  --from-literal=MONGODB_URI="mongodb://<new-credentials>@<host>:27017/tasky" \
  -n tasky

# 7. Restart application
kubectl rollout restart deployment/tasky -n tasky
```

---

### S3 Data Exfiltration Detected

**Indicators:**
- GuardDuty: S3 anonymous access
- CloudTrail: GetObject from unknown IPs
- Unusual egress traffic

**Response Steps:**

```bash
# 1. ASSESS - Check bucket access
aws s3api get-bucket-policy --bucket wiz-exercise-backup-<suffix>
aws s3api get-bucket-acl --bucket wiz-exercise-backup-<suffix>
aws s3api get-public-access-block --bucket wiz-exercise-backup-<suffix>

# 2. CONTAIN - Block public access immediately
aws s3api put-public-access-block \
  --bucket wiz-exercise-backup-<suffix> \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 3. INVESTIGATE - Review access logs
aws s3 cp s3://wiz-exercise-backup-<suffix>-logs/ ./logs/ --recursive
# Analyze server access logs

# 4. ASSESS IMPACT
# List what was accessible
aws s3 ls s3://wiz-exercise-backup-<suffix>/ --recursive

# 5. RECOVER
# Update Terraform to prevent recurrence
# Add: block_public_acls = true, etc.
terraform apply
```

---

## Maintenance Tasks

### Rotate SSH Keys

**When:** Regular rotation, suspected compromise

**Steps:**

```bash
# 1. Generate new key pair
aws ec2 create-key-pair \
  --key-name wiz-exercise-mongodb-$(date +%Y%m%d) \
  --query 'KeyMaterial' \
  --output text > keys/mongodb-new.pem
chmod 600 keys/mongodb-new.pem

# 2. Add new key to instance
# Via SSM or existing SSH:
echo "ssh-rsa <new-public-key>" >> /home/ubuntu/.ssh/authorized_keys

# 3. Test new key
ssh -i keys/mongodb-new.pem ubuntu@<ip>

# 4. Remove old key
# On instance:
# Edit /home/ubuntu/.ssh/authorized_keys, remove old key

# 5. Update SSM Parameter
aws ssm put-parameter \
  --name "/wiz-exercise/ssh-keys/mongodb" \
  --type "SecureString" \
  --value "$(cat keys/mongodb-new.pem)" \
  --overwrite

# 6. Delete old key pair
aws ec2 delete-key-pair --key-name wiz-exercise-mongodb-old
```

---

### Update MongoDB Password

**When:** Regular rotation, suspected compromise

**Steps:**

```bash
# 1. SSH to MongoDB instance
make ssh-mongodb

# 2. Connect to MongoDB
mongo -u admin -p '<current-password>' --authenticationDatabase admin

# 3. Update passwords
use admin
db.changeUserPassword("admin", "<new-admin-password>")
db.changeUserPassword("taskyuser", "<new-app-password>")

# 4. Update Kubernetes secret
kubectl delete secret mongodb-credentials -n tasky
kubectl create secret generic mongodb-credentials \
  --from-literal=MONGODB_URI="mongodb://taskyuser:<new-app-password>@<mongodb-ip>:27017/tasky?authSource=admin" \
  -n tasky

# 5. Restart application
kubectl rollout restart deployment/tasky -n tasky

# 6. Update Terraform variables for future deployments
export TF_VAR_mongodb_admin_pass="<new-admin-password>"
export TF_VAR_mongodb_app_pass="<new-app-password>"
```

---

### Check and Clean S3 Backups

**When:** Storage management, cost control

**Steps:**

```bash
# 1. List backups
aws s3 ls s3://wiz-exercise-backup-<suffix>/ --recursive --human-readable

# 2. Check total size
aws s3 ls s3://wiz-exercise-backup-<suffix>/ --recursive --summarize

# 3. Remove old backups (keep last 7 days)
aws s3 rm s3://wiz-exercise-backup-<suffix>/ \
  --recursive \
  --exclude "*" \
  --include "backup-*.gz" \
  --dryrun  # Remove --dryrun to execute

# 4. Set lifecycle policy (automate cleanup)
aws s3api put-bucket-lifecycle-configuration \
  --bucket wiz-exercise-backup-<suffix> \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "DeleteOldBackups",
      "Status": "Enabled",
      "Filter": {"Prefix": "backup-"},
      "Expiration": {"Days": 30}
    }]
  }'
```

---

## Disaster Recovery

### Full Environment Recreation

**When:** Complete environment failure, DR test

**Recovery Time Objective (RTO):** ~30 minutes
**Recovery Point Objective (RPO):** Last backup (if applicable)

**Steps:**

```bash
# 1. Verify AWS access
aws sts get-caller-identity

# 2. Check Terraform state
terraform -chdir=terraform init
terraform -chdir=terraform state list

# 3. If state is intact, redeploy
terraform -chdir=terraform apply -var-file=environments/demo.tfvars

# 4. If state is lost, import or recreate
# Option A: Recreate from scratch
terraform -chdir=terraform destroy -var-file=environments/demo.tfvars
terraform -chdir=terraform apply -var-file=environments/demo.tfvars

# Option B: Import existing resources (if they exist)
# terraform import module.vpc.aws_vpc.main vpc-xxxxxxxx
# (Repeat for each resource)

# 5. Restore data from backup (if needed)
# Download from S3
aws s3 cp s3://wiz-exercise-backup-<suffix>/backup-latest.gz ./

# Restore to MongoDB
make ssh-mongodb
mongorestore --gzip --archive=backup-latest.gz
```

---

### EKS Cluster Recovery

**When:** Cluster unreachable, control plane issues

**Steps:**

```bash
# 1. Check cluster status
aws eks describe-cluster --name wiz-exercise-eks

# 2. If cluster exists but unreachable
# Update kubeconfig
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1

# 3. If node group unhealthy
aws eks describe-nodegroup \
  --cluster-name wiz-exercise-eks \
  --nodegroup-name wiz-exercise-nodes

# Recreate node group
terraform -chdir=terraform taint 'module.eks.aws_eks_node_group.main'
terraform -chdir=terraform apply -var-file=environments/demo.tfvars

# 4. If cluster needs recreation
terraform -chdir=terraform taint 'module.eks.aws_eks_cluster.main'
terraform -chdir=terraform apply -var-file=environments/demo.tfvars

# 5. Redeploy application
kubectl apply -f k8s/
```

---

## Runbook Maintenance

### Updating Runbooks

When updating these runbooks:

1. Test procedures in a non-production environment
2. Include expected outputs where helpful
3. Note any prerequisites or dependencies
4. Add verification steps
5. Update the table of contents

### Runbook Review Schedule

| Review Type | Frequency |
|-------------|-----------|
| Full review | Quarterly |
| Incident-triggered | After each incident |
| Change-triggered | After infrastructure changes |

## Related Documentation

- [Troubleshooting - Common Issues](../troubleshooting/common-issues.md)
- [Architecture Overview](../architecture/overview.md)
- [Security Overview](../security/overview.md)
- [Demos - Detection & Response](../demos/detection.md)
