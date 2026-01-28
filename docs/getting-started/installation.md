# Installation

This guide covers setting up the Wiz Technical Exercise project on your local machine.

## Clone the Repository

### Via HTTPS

```bash
git clone https://github.com/evanspangler/wiz-technical-exercise.git
cd wiz-technical-exercise
```

### Via SSH

```bash
git clone git@github.com:evanspangler/wiz-technical-exercise.git
cd wiz-technical-exercise
```

### Via GitHub CLI

```bash
gh repo clone evanspangler/wiz-technical-exercise
cd wiz-technical-exercise
```

## Project Structure

After cloning, you'll have this structure:

```
wiz-technical-exercise/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD
├── docs/                       # Documentation (this site)
├── k8s/                        # Kubernetes manifests
│   ├── namespace.yaml          # Tasky namespace
│   ├── deployment.yaml         # App deployment
│   ├── service.yaml            # LoadBalancer service
│   ├── serviceaccount.yaml     # Overprivileged SA
│   └── secrets.yaml            # K8s secrets
├── keys/                       # SSH keys (git-ignored)
├── terraform/
│   ├── bootstrap/              # State backend setup
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── environments/
│   │   └── demo.tfvars         # Demo configuration
│   └── modules/
│       ├── eks/                # EKS cluster module
│       ├── mongodb-vm/         # MongoDB EC2 module
│       ├── networking/         # VPC module
│       ├── redteam/            # Red team instance
│       ├── s3-backup/          # S3 bucket module
│       └── wazuh/              # Wazuh SIEM module
├── .env.example                # Environment template
├── .gitignore                  # Git ignore rules
├── Makefile                    # Build automation
├── mkdocs.yml                  # Docs configuration
└── README.md                   # Project readme
```

## Environment Setup

### Create Environment File

Copy the example environment file:

```bash
cp .env.example .env
```

### Configure AWS Credentials

Edit `.env` with your AWS credentials:

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# MongoDB Passwords
MONGODB_ADMIN_PASS=SecureAdminPassword123!
MONGODB_APP_PASS=SecureAppPassword456!

# Backup Encryption
BACKUP_ENCRYPTION_KEY=your-32-char-encryption-key

# Wazuh Credentials (optional - will be auto-generated)
WAZUH_ADMIN_PASS=WazuhAdmin789!
WAZUH_API_PASS=WazuhAPI012!
```

!!! warning "Never Commit Credentials"
    The `.env` file is in `.gitignore`. Never commit credentials to version control.

### Verify AWS Access

Test your credentials:

```bash
source .env
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

## Bootstrap Terraform Backend

Before the first deployment, create the Terraform state backend:

```bash
make bootstrap
```

This creates:

- **S3 Bucket**: `wiz-exercise-tfstate-{random}` for state storage
- **DynamoDB Table**: `wiz-exercise-tfstate-lock` for state locking

Output:

```
Bootstrapping Terraform state backend...

Initializing the backend...
Initializing provider plugins...

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

bucket_name = "wiz-exercise-tfstate-abc123"
dynamodb_table = "wiz-exercise-tfstate-lock"
```

## Initialize Terraform

Initialize the main Terraform configuration:

```bash
make init
```

This downloads providers and modules:

```
Initializing the backend...

Successfully configured the backend "s3"!

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Finding hashicorp/kubernetes versions matching "~> 2.0"...
- Installing hashicorp/aws v5.x.x...
- Installing hashicorp/kubernetes v2.x.x...

Terraform has been successfully initialized!
```

## Configure GitHub Actions (Optional)

If deploying via GitHub Actions:

### 1. Push to GitHub

```bash
git remote add origin https://github.com/your-username/wiz-technical-exercise.git
git push -u origin main
```

### 2. Configure Secrets

Upload secrets to GitHub:

```bash
make secrets
```

Or manually via GitHub UI:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add each secret:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `MONGODB_ADMIN_PASS`
   - `MONGODB_APP_PASS`
   - `BACKUP_ENCRYPTION_KEY`
   - `WAZUH_ADMIN_PASS`
   - `WAZUH_API_PASS`

### 3. Enable Actions

Ensure GitHub Actions is enabled:

1. Go to **Settings** → **Actions** → **General**
2. Select "Allow all actions and reusable workflows"

## Verify Installation

Run the verification:

```bash
# Check Makefile targets
make help

# Verify Terraform configuration
make plan
```

If `make plan` completes without errors, installation is successful.

## Directory Permissions

Ensure correct permissions for SSH keys directory:

```bash
mkdir -p keys
chmod 700 keys
```

SSH keys will be stored here after deployment with mode `600`.

## IDE Setup (Optional)

### VS Code Extensions

Recommended extensions for development:

```json
{
  "recommendations": [
    "hashicorp.terraform",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "redhat.vscode-yaml",
    "ms-azuretools.vscode-docker"
  ]
}
```

### Terraform Language Server

For Terraform IntelliSense:

```bash
# macOS
brew install terraform-ls

# Linux
wget https://releases.hashicorp.com/terraform-ls/0.32.0/terraform-ls_0.32.0_linux_amd64.zip
unzip terraform-ls_0.32.0_linux_amd64.zip
sudo mv terraform-ls /usr/local/bin/
```

## Troubleshooting Installation

### Common Issues

**Error: Backend configuration changed**

```bash
terraform init -reconfigure
```

**Error: Provider version constraints**

```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
```

**Error: AWS credentials not found**

```bash
# Verify environment variables
echo $AWS_ACCESS_KEY_ID
source .env
```

**Error: Permission denied on keys/**

```bash
chmod 700 keys
chmod 600 keys/*.pem
```

## Next Steps

After installation:

1. [Configuration](configuration.md) - Review all configuration options
2. [Quick Start](quickstart.md) - Deploy the infrastructure
3. [Architecture Overview](../architecture/overview.md) - Understand the system
