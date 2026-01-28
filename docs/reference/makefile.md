# Makefile Commands Reference

Complete reference for all Makefile targets in the Wiz Technical Exercise.

## Quick Reference

```bash
make help  # Show all available commands
```

## Build & Deploy

### `make build`

Deploy infrastructure via GitHub Actions (recommended method).

```bash
make build
```

**What it does:**

1. Triggers GitHub Actions workflow with `action=apply`
2. Waits for workflow completion (`make watch`)
3. Fetches SSH keys (`make ssh-keys`)

**Prerequisites:**

- GitHub CLI authenticated (`gh auth login`)
- GitHub secrets configured (`make secrets`)

---

### `make deploy`

Alias for `make build`.

---

### `make deploy-local`

Deploy infrastructure directly from local machine.

```bash
make deploy-local
```

**What it does:**

1. Runs `terraform init`
2. Runs `terraform apply` with demo.tfvars
3. Fetches SSH keys

**Prerequisites:**

- AWS credentials in `.env`
- Terraform state backend bootstrapped

---

### `make bootstrap`

Create Terraform state backend (S3 bucket + DynamoDB table).

```bash
make bootstrap
```

**Run once** before first deployment.

---

### `make secrets`

Upload secrets to GitHub for Actions workflow.

```bash
make secrets
```

**Secrets configured:**

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `MONGODB_ADMIN_PASS`
- `MONGODB_APP_PASS`
- `BACKUP_ENCRYPTION_KEY`
- `WAZUH_ADMIN_PASS`
- `WAZUH_API_PASS`

---

### `make init`

Initialize Terraform working directory.

```bash
make init
```

---

### `make plan`

Show Terraform execution plan.

```bash
make plan
```

---

### `make apply`

Apply Terraform changes (with confirmation).

```bash
make apply
```

## SSH Access

### `make ssh-keys`

Fetch SSH private keys from AWS SSM and store locally.

```bash
make ssh-keys
```

**Output:**

```
Fetching SSH keys from AWS SSM...
[OK] keys/mongodb.pem
[OK] keys/wazuh.pem
[OK] keys/redteam.pem
```

Keys are stored in `keys/` directory with mode `600`.

---

### `make ssh-info`

Display SSH connection commands for all instances.

```bash
make ssh-info
```

**Output:**

```
═══════════════════════════════════════════════════════════════
                    SSH CONNECTION INFO
═══════════════════════════════════════════════════════════════

MongoDB:    ssh -i keys/mongodb.pem ubuntu@54.221.160.152
Wazuh:      ssh -i keys/wazuh.pem ubuntu@54.198.244.72
Dashboard:  https://54.198.244.72 (user: admin)
Red Team:   ssh -i keys/redteam.pem ubuntu@52.91.31.40

═══════════════════════════════════════════════════════════════
```

---

### `make ssh-mongodb`

SSH directly to MongoDB instance.

```bash
make ssh-mongodb
```

Automatically fetches keys if not present.

---

### `make ssh-wazuh`

SSH directly to Wazuh instance.

```bash
make ssh-wazuh
```

---

### `make ssh-redteam`

SSH directly to Red Team instance.

```bash
make ssh-redteam
```

## Destroy & Reset

### `make destroy`

Destroy infrastructure via GitHub Actions.

```bash
make destroy
```

**Requires confirmation:** Type `DESTROY` when prompted.

---

### `make destroy-local`

Destroy infrastructure from local machine.

```bash
make destroy-local
```

**Requires confirmation:** Type `DESTROY` when prompted.

---

### `make reset`

Complete reset: destroy infrastructure and clean local files.

```bash
make reset
```

Equivalent to: `make destroy` + `make clean`

---

### `make clean`

Remove local Terraform files and SSH keys.

```bash
make clean
```

**Removes:**

- `terraform/.terraform/`
- `terraform/.terraform.lock.hcl`
- `terraform/tfplan*`
- `terraform/terraform.tfstate*`
- `terraform/bootstrap/.terraform/`
- `keys/`

---

### `make force-destroy`

Emergency force cleanup of AWS resources.

```bash
make force-destroy
```

**Requires confirmation:** Type `FORCE` when prompted.

**Actions:**

1. Terminates all EC2 instances tagged `Project=wiz-exercise`
2. Deletes EKS node group
3. Deletes EKS cluster
4. Empties and deletes S3 buckets

!!! warning "Use with caution"
    This bypasses Terraform state. Use only when normal destroy fails.

## Demos

### `make demo`

Show interactive demo menu.

```bash
make demo
```

**Output:**

```
═══════════════════════════════════════════════════════════════
                  VULNERABILITY DEMOS
═══════════════════════════════════════════════════════════════

  1) make demo-s3       - Public S3 bucket access
  2) make demo-ssh      - SSH to exposed MongoDB
  3) make demo-iam      - Overprivileged IAM role
  4) make demo-k8s      - K8s cluster-admin abuse
  5) make demo-secrets  - K8s secrets exposure
  6) make demo-redteam  - SSH to red team instance
  7) make demo-wazuh    - Wazuh SIEM dashboard
  8) make demo-attack   - Full attack chain
```

---

### `make demo-s3`

Demonstrate public S3 bucket vulnerability.

```bash
make demo-s3
```

Shows:
- Listing bucket contents without authentication
- Reading files from public bucket

---

### `make demo-ssh`

SSH to MongoDB instance (demonstrates exposed SSH).

```bash
make demo-ssh
```

---

### `make demo-iam`

Explain overprivileged IAM role permissions.

```bash
make demo-iam
```

Shows commands that can be run from MongoDB instance.

---

### `make demo-k8s`

Demonstrate Kubernetes cluster-admin vulnerability.

```bash
make demo-k8s
```

Shows:
- ClusterRoleBinding configuration
- Potential impact

---

### `make demo-secrets`

Extract and decode Kubernetes secrets.

```bash
make demo-secrets
```

Shows:
- Secrets in tasky namespace
- Decoded MongoDB URI
- Decoded JWT secret

---

### `make demo-redteam`

SSH to Red Team instance with attack tools.

```bash
make demo-redteam
```

---

### `make demo-wazuh`

Open Wazuh SIEM dashboard in browser.

```bash
make demo-wazuh
```

---

### `make demo-attack`

Display full attack chain walkthrough.

```bash
make demo-attack
```

## Status & Info

### `make show`

Display all deployed infrastructure.

```bash
make show
```

**Shows:**

- EC2 instances (name, ID, state, public IP)
- S3 buckets
- EKS cluster status
- Kubernetes pods

---

### `make status`

Show GitHub Actions workflow status.

```bash
make status
```

Lists last 5 workflow runs.

---

### `make outputs`

Display Terraform outputs.

```bash
make outputs
```

---

### `make logs`

Show logs from latest GitHub Actions workflow.

```bash
make logs
```

---

### `make watch`

Watch running GitHub Actions workflow.

```bash
make watch
```

Waits for workflow completion with live updates.

## Environment Variables

### Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `TF_DIR` | `terraform` | Terraform directory |
| `ENV_FILE` | `.env` | Environment file |

### Override Examples

```bash
# Use different region
make build AWS_REGION=us-west-2

# Use different env file
make build ENV_FILE=.env.prod
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Command failed |
| 2 | User cancelled (confirmation) |

## Examples

### Full Deployment Workflow

```bash
# First time setup
make bootstrap
make secrets

# Deploy
make build

# Get access info
make ssh-info

# Run demos
make demo-s3
make demo-secrets

# Cleanup
make destroy
```

### Local Development

```bash
# Initialize
make init

# Preview changes
make plan

# Apply
make apply

# Access instances
make ssh-mongodb
make ssh-redteam

# Cleanup
make destroy-local
make clean
```
