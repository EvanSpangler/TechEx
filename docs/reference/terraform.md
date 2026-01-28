# Terraform Modules

Reference documentation for Terraform modules.

## Module Structure

```
terraform/
├── main.tf              # Root module
├── variables.tf         # Input variables
├── outputs.tf           # Outputs
├── providers.tf         # Provider config
├── backend.tf           # State backend
├── environments/
│   └── demo.tfvars      # Environment config
└── modules/
    ├── eks/             # EKS cluster
    ├── mongodb-vm/      # MongoDB instance
    ├── networking/      # VPC and subnets
    ├── redteam/         # Red team instance
    ├── s3-backup/       # S3 bucket
    └── wazuh/           # Wazuh SIEM
```

## Module: networking

Creates VPC, subnets, gateways, and route tables.

### Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `vpc_cidr` | string | VPC CIDR block |
| `availability_zones` | list | AZs to use |
| `project_name` | string | Name prefix |

### Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |

## Module: eks

Creates EKS cluster and managed node group.

### Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `cluster_name` | string | Cluster name |
| `cluster_version` | string | K8s version |
| `vpc_id` | string | VPC ID |
| `subnet_ids` | list | Subnet IDs |

### Outputs

| Output | Description |
|--------|-------------|
| `cluster_endpoint` | API endpoint |
| `cluster_name` | Cluster name |

## Module: mongodb-vm

Creates MongoDB EC2 instance with intentional vulnerabilities.

### Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `instance_type` | string | EC2 instance type |
| `mongodb_admin_pass` | string | Admin password |
| `mongodb_app_pass` | string | App password |

### Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Public IP |
| `private_ip` | Private IP |

## Module: s3-backup

Creates publicly accessible S3 bucket (intentional vulnerability).

### Outputs

| Output | Description |
|--------|-------------|
| `bucket_name` | Bucket name |
| `bucket_arn` | Bucket ARN |

## Module: wazuh

Creates Wazuh SIEM instance.

### Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Dashboard IP |

## Module: redteam

Creates pre-configured attack instance.

### Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Instance IP |
