# Prerequisites

Before deploying the Wiz Technical Exercise, ensure you have the following tools and access configured.

## Required Tools

### AWS CLI v2

The AWS Command Line Interface is required for interacting with AWS services.

=== "macOS"

    ```bash
    brew install awscli
    ```

=== "Linux"

    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```

=== "Windows"

    Download and run the [AWS CLI MSI installer](https://awscli.amazonaws.com/AWSCLIV2.msi)

Verify installation:

```bash
aws --version
# aws-cli/2.x.x Python/3.x.x ...
```

### Terraform >= 1.0

Infrastructure as Code tool for provisioning AWS resources.

=== "macOS"

    ```bash
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
    ```

=== "Linux"

    ```bash
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
    ```

Verify installation:

```bash
terraform --version
# Terraform v1.x.x
```

### kubectl

Kubernetes command-line tool for cluster management.

=== "macOS"

    ```bash
    brew install kubectl
    ```

=== "Linux"

    ```bash
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    ```

Verify installation:

```bash
kubectl version --client
```

### GitHub CLI

Command-line tool for GitHub operations (required for GitHub Actions deployment).

=== "macOS"

    ```bash
    brew install gh
    ```

=== "Linux"

    ```bash
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install gh
    ```

Authenticate with GitHub:

```bash
gh auth login
```

### Make

GNU Make for build automation.

=== "macOS"

    ```bash
    # Included with Xcode Command Line Tools
    xcode-select --install
    ```

=== "Linux"

    ```bash
    sudo apt install make
    # or
    sudo yum install make
    ```

### jq (Optional but Recommended)

JSON processor for parsing AWS CLI output.

=== "macOS"

    ```bash
    brew install jq
    ```

=== "Linux"

    ```bash
    sudo apt install jq
    ```

## AWS Account Requirements

### Dedicated Account

!!! danger "Important"
    **Use a dedicated AWS account** for this exercise. The infrastructure is intentionally vulnerable and should not be deployed alongside production resources.

Consider using:

- AWS Organizations member account
- Separate personal account
- Sandbox/training account

### IAM Permissions

The deploying IAM user/role needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "s3:*",
        "iam:*",
        "ssm:*",
        "kms:*",
        "logs:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "cloudwatch:*",
        "secretsmanager:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

!!! tip "Least Privilege"
    For production deployments, create a more restrictive policy. The above is intentionally broad for ease of use in a training environment.

### Service Quotas

Ensure your account has sufficient quotas:

| Service | Resource | Minimum Required |
|---------|----------|-----------------|
| EC2 | vCPUs (On-Demand) | 12 |
| EC2 | Elastic IPs | 4 |
| VPC | VPCs per region | 1 |
| VPC | NAT Gateways | 1 |
| EKS | Clusters | 1 |
| S3 | Buckets | 3 |

Check your quotas:

```bash
aws service-quotas list-service-quotas --service-code ec2 --query 'Quotas[?QuotaName==`Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances`]'
```

### Region Selection

Default region is `us-east-1`. Ensure you have:

- No conflicting resources with the same names
- Sufficient capacity for EKS and EC2
- Access to the region (no SCPs blocking)

To use a different region, set:

```bash
export AWS_REGION=us-west-2
```

## GitHub Requirements

### Repository Access

If using GitHub Actions:

1. Fork or clone the repository
2. Ensure GitHub Actions is enabled
3. Configure repository secrets (see [Configuration](configuration.md))

### Required Secrets

The following secrets must be configured in GitHub:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `MONGODB_ADMIN_PASS` | MongoDB admin password |
| `MONGODB_APP_PASS` | MongoDB application password |
| `BACKUP_ENCRYPTION_KEY` | Backup encryption key |
| `WAZUH_ADMIN_PASS` | Wazuh dashboard password |
| `WAZUH_API_PASS` | Wazuh API password |

## Network Requirements

### Outbound Access

Your deployment environment needs outbound access to:

- AWS APIs (various endpoints)
- GitHub (for Actions and CLI)
- Docker Hub (for container images)
- Terraform Registry
- Ubuntu package repositories

### Firewall Considerations

If behind a corporate firewall, ensure these ports are open:

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 443 | HTTPS | *.amazonaws.com | AWS APIs |
| 443 | HTTPS | github.com | GitHub |
| 443 | HTTPS | registry.terraform.io | Terraform |
| 22 | SSH | Deployed EC2 IPs | Instance access |

## Verification Script

Run this script to verify all prerequisites:

```bash
#!/bin/bash
echo "Checking prerequisites..."

# AWS CLI
if command -v aws &> /dev/null; then
    echo "✓ AWS CLI: $(aws --version 2>&1 | head -1)"
else
    echo "✗ AWS CLI not found"
fi

# Terraform
if command -v terraform &> /dev/null; then
    echo "✓ Terraform: $(terraform --version | head -1)"
else
    echo "✗ Terraform not found"
fi

# kubectl
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    echo "✗ kubectl not found"
fi

# GitHub CLI
if command -v gh &> /dev/null; then
    echo "✓ GitHub CLI: $(gh --version | head -1)"
else
    echo "✗ GitHub CLI not found"
fi

# Make
if command -v make &> /dev/null; then
    echo "✓ Make: $(make --version | head -1)"
else
    echo "✗ Make not found"
fi

# AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    echo "✓ AWS credentials configured"
    aws sts get-caller-identity --query 'Arn' --output text
else
    echo "✗ AWS credentials not configured"
fi

# GitHub auth
if gh auth status &> /dev/null; then
    echo "✓ GitHub CLI authenticated"
else
    echo "✗ GitHub CLI not authenticated"
fi
```

Save as `check-prereqs.sh` and run:

```bash
chmod +x check-prereqs.sh
./check-prereqs.sh
```

## Next Steps

Once all prerequisites are met:

1. [Installation](installation.md) - Set up the project
2. [Configuration](configuration.md) - Configure environment variables
3. [Quick Start](quickstart.md) - Deploy the infrastructure
