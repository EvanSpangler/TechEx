# Terraform Outputs

Reference for all Terraform outputs.

## Viewing Outputs

```bash
make outputs
# or
cd terraform && terraform output
```

## Available Outputs

### Network

| Output | Description | Example |
|--------|-------------|---------|
| `vpc_id` | VPC identifier | `vpc-0abc123...` |
| `public_subnet_ids` | Public subnet IDs | `["subnet-abc", "subnet-def"]` |
| `private_subnet_ids` | Private subnet IDs | `["subnet-123", "subnet-456"]` |

### EKS

| Output | Description | Example |
|--------|-------------|---------|
| `eks_cluster_endpoint` | Kubernetes API endpoint | `https://xxx.eks.amazonaws.com` |
| `eks_cluster_name` | Cluster name | `wiz-exercise-eks` |

### EC2 Instances

| Output | Description | Example |
|--------|-------------|---------|
| `mongodb_public_ip` | MongoDB public IP | `54.221.160.152` |
| `mongodb_private_ip` | MongoDB private IP | `10.0.1.50` |
| `wazuh_public_ip` | Wazuh dashboard IP | `54.198.244.72` |
| `redteam_public_ip` | Red team instance IP | `52.91.31.40` |

### S3

| Output | Description | Example |
|--------|-------------|---------|
| `backup_bucket_name` | Backup bucket name | `wiz-exercise-backups-abc123` |

## Usage in Scripts

```bash
# Get specific output
MONGODB_IP=$(cd terraform && terraform output -raw mongodb_public_ip)

# Use in SSH
ssh -i keys/mongodb.pem ubuntu@$MONGODB_IP
```

## JSON Output

```bash
terraform output -json
```
