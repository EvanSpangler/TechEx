# Configuration

Complete reference for all configuration options in the Wiz Technical Exercise.

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key for deployment | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/...` |
| `MONGODB_ADMIN_PASS` | MongoDB administrator password | `SecureAdmin123!` |
| `MONGODB_APP_PASS` | MongoDB application user password | `SecureApp456!` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region for deployment | `us-east-1` |
| `BACKUP_ENCRYPTION_KEY` | GPG encryption key for backups | Auto-generated |
| `WAZUH_ADMIN_PASS` | Wazuh dashboard password | Auto-generated |
| `WAZUH_API_PASS` | Wazuh API password | Auto-generated |

### Environment File

Create `.env` from the template:

```bash
cp .env.example .env
```

Example `.env`:

```bash
# AWS Credentials (required)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# MongoDB Configuration (required)
MONGODB_ADMIN_PASS=MongoDBAdmin@Wiz2024!
MONGODB_APP_PASS=MongoDBApp@Wiz2024!

# Backup Encryption (optional - auto-generated if empty)
BACKUP_ENCRYPTION_KEY=

# Wazuh SIEM (optional - auto-generated if empty)
WAZUH_ADMIN_PASS=
WAZUH_API_PASS=
```

!!! warning "File Format"
    Do not use quotes around values in `.env` when using with Make:

    ```bash
    # Correct
    AWS_ACCESS_KEY_ID=AKIA...

    # Incorrect (quotes become part of value)
    AWS_ACCESS_KEY_ID="AKIA..."
    ```

## Terraform Variables

### Main Variables (terraform/variables.tf)

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `environment` | string | Environment name | `demo` |
| `aws_region` | string | AWS region | `us-east-1` |
| `project_name` | string | Project name for tagging | `wiz-exercise` |
| `vpc_cidr` | string | VPC CIDR block | `10.0.0.0/16` |
| `availability_zones` | list | AZs to use | `["us-east-1a", "us-east-1b"]` |

### EKS Configuration

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `eks_cluster_version` | string | Kubernetes version | `1.28` |
| `eks_node_instance_type` | string | Node instance type | `t3.medium` |
| `eks_node_desired_size` | number | Desired node count | `2` |
| `eks_node_min_size` | number | Minimum nodes | `1` |
| `eks_node_max_size` | number | Maximum nodes | `3` |

### MongoDB Configuration

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `mongodb_instance_type` | string | EC2 instance type | `t3.small` |
| `mongodb_version` | string | MongoDB version | `4.4` |
| `mongodb_admin_user` | string | Admin username | `admin` |
| `mongodb_database` | string | Database name | `tasky` |
| `mongodb_app_user` | string | App username | `tasky` |

### Wazuh Configuration

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `wazuh_instance_type` | string | EC2 instance type | `t3.medium` |
| `wazuh_version` | string | Wazuh version | `4.7.0` |

### Environment File (terraform/environments/demo.tfvars)

```hcl
# Environment
environment = "demo"
aws_region  = "us-east-1"

# Networking
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# EKS
eks_cluster_version    = "1.28"
eks_node_instance_type = "t3.medium"
eks_node_desired_size  = 2

# MongoDB
mongodb_instance_type = "t3.small"

# Wazuh
wazuh_instance_type = "t3.medium"

# Red Team
redteam_instance_type = "t3.small"
```

## Makefile Configuration

### Configurable Variables

At the top of the Makefile:

```makefile
# Configuration
SHELL := /bin/bash
AWS_REGION ?= us-east-1
TF_DIR := terraform
BOOTSTRAP_DIR := terraform/bootstrap
ENV_FILE := .env
```

### Override via Command Line

```bash
# Use different region
make build AWS_REGION=us-west-2

# Use different environment file
make build ENV_FILE=.env.production
```

### Override via Environment

```bash
export AWS_REGION=eu-west-1
make build
```

## GitHub Actions Configuration

### Workflow Variables

In `.github/workflows/deploy.yml`:

```yaml
env:
  AWS_REGION: us-east-1
  TF_VERSION: 1.5.0
  WORKING_DIR: terraform
```

### Secrets Configuration

Required GitHub Secrets:

| Secret | Description | Required |
|--------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Yes |
| `MONGODB_ADMIN_PASS` | MongoDB admin password | Yes |
| `MONGODB_APP_PASS` | MongoDB app password | Yes |
| `BACKUP_ENCRYPTION_KEY` | Backup encryption key | No |
| `WAZUH_ADMIN_PASS` | Wazuh admin password | No |
| `WAZUH_API_PASS` | Wazuh API password | No |

### Configuring Secrets via CLI

```bash
# Set all secrets at once
make secrets

# Or individually
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
```

### Workflow Inputs

The deploy workflow accepts inputs:

```yaml
workflow_dispatch:
  inputs:
    action:
      description: 'Action to perform'
      required: true
      default: 'plan'
      type: choice
      options:
        - plan
        - apply
        - destroy
```

Trigger via CLI:

```bash
# Plan only
gh workflow run "Deploy Infrastructure" --field action=plan

# Apply changes
gh workflow run "Deploy Infrastructure" --field action=apply

# Destroy infrastructure
gh workflow run "Deploy Infrastructure" --field action=destroy
```

## Kubernetes Configuration

### Namespace Configuration

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tasky
  labels:
    app: tasky
    environment: demo
```

### Secret Configuration

```yaml
# k8s/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-credentials
  namespace: tasky
type: Opaque
stringData:
  MONGODB_URI: mongodb://user:pass@host:27017/db
  SECRET_KEY: jwt-secret-key
```

!!! danger "Plain Text Secrets"
    This is an intentional vulnerability. In production, use:

    - AWS Secrets Manager with External Secrets Operator
    - HashiCorp Vault
    - Sealed Secrets

## SSH Configuration

### SSH Keys Location

Keys are stored in `keys/` directory (git-ignored):

```
keys/
├── mongodb.pem    # MongoDB instance
├── wazuh.pem      # Wazuh instance
└── redteam.pem    # Red Team instance
```

### SSH Config Example

Add to `~/.ssh/config`:

```
Host wiz-mongodb
    HostName 54.x.x.x
    User ubuntu
    IdentityFile ~/wiz-technical-exercise/keys/mongodb.pem
    StrictHostKeyChecking no

Host wiz-wazuh
    HostName 54.x.x.x
    User ubuntu
    IdentityFile ~/wiz-technical-exercise/keys/wazuh.pem
    StrictHostKeyChecking no

Host wiz-redteam
    HostName 52.x.x.x
    User ubuntu
    IdentityFile ~/wiz-technical-exercise/keys/redteam.pem
    StrictHostKeyChecking no
```

Then connect with:

```bash
ssh wiz-mongodb
ssh wiz-wazuh
ssh wiz-redteam
```

## Network Configuration

### VPC CIDR Allocation

| Subnet | CIDR | Purpose |
|--------|------|---------|
| VPC | 10.0.0.0/16 | Main VPC |
| Public Subnet A | 10.0.1.0/24 | Public resources AZ-a |
| Public Subnet B | 10.0.2.0/24 | Public resources AZ-b |
| Private Subnet A | 10.0.10.0/24 | EKS nodes AZ-a |
| Private Subnet B | 10.0.11.0/24 | EKS nodes AZ-b |

### Security Group Rules

Default security groups allow:

| Resource | Inbound | Source | Note |
|----------|---------|--------|------|
| MongoDB | 22 | 0.0.0.0/0 | **Intentionally exposed** |
| MongoDB | 27017 | VPC CIDR | Database |
| Wazuh | 443 | 0.0.0.0/0 | Dashboard |
| Wazuh | 1514 | VPC CIDR | Agent |
| ALB | 80, 443 | 0.0.0.0/0 | Web traffic |

## Advanced Configuration

### Custom Terraform Backend

To use a different backend:

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-custom-bucket"
    key            = "wiz-exercise/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-lock-table"
    encrypt        = true
  }
}
```

### Multiple Environments

Create additional tfvars files:

```bash
# terraform/environments/
├── demo.tfvars
├── staging.tfvars
└── production.tfvars
```

Deploy specific environment:

```bash
cd terraform
terraform apply -var-file="environments/staging.tfvars"
```

### Custom Tags

Add tags to all resources:

```hcl
# In your tfvars
tags = {
  Project     = "wiz-exercise"
  Environment = "demo"
  Owner       = "your-name"
  CostCenter  = "security-training"
}
```
