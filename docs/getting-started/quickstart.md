# Quick Start Guide

Get up and running with the Wiz Technical Exercise in under 10 minutes.

## TL;DR

```bash
# Clone, configure, deploy
git clone https://github.com/evanspangler/wiz-technical-exercise.git
cd wiz-technical-exercise
cp .env.example .env
# Edit .env with your AWS credentials
make secrets
make build
```

## Step-by-Step

### 1. Clone the Repository

```bash
git clone https://github.com/evanspangler/wiz-technical-exercise.git
cd wiz-technical-exercise
```

### 2. Configure Environment

Create your environment file:

```bash
cp .env.example .env
```

Edit `.env` with your AWS credentials:

```bash
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
MONGODB_ADMIN_PASS=your-secure-password
MONGODB_APP_PASS=your-app-password
BACKUP_ENCRYPTION_KEY=your-encryption-key
```

!!! warning "Security Note"
    Use a dedicated AWS account for this exercise. The infrastructure is intentionally vulnerable.

### 3. Bootstrap Terraform Backend

First-time setup requires creating the S3 backend:

```bash
make bootstrap
```

This creates:

- S3 bucket for Terraform state
- DynamoDB table for state locking

### 4. Configure GitHub Secrets

If using GitHub Actions for deployment:

```bash
make secrets
```

This uploads your credentials to GitHub Secrets.

### 5. Deploy Infrastructure

=== "Via GitHub Actions"

    ```bash
    make build
    ```

    This triggers a GitHub Actions workflow and waits for completion.

=== "Local Deployment"

    ```bash
    make deploy-local
    ```

    Runs Terraform directly on your machine.

### 6. Get SSH Access

After deployment, fetch the SSH keys:

```bash
make ssh-keys
```

View connection info:

```bash
make ssh-info
```

Output:

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

### 7. Verify Deployment

Check infrastructure status:

```bash
make show
```

Output:

```
EC2 Instances:
------------------------------------------------------------------
|                      DescribeInstances                         |
+--------------------+----------------------+----------+----------+
|        Name        |          ID          |  State   | PublicIP |
+--------------------+----------------------+----------+----------+
|  wiz-mongodb       |  i-0abc123def456789  |  running | 54.x.x.x |
|  wiz-wazuh         |  i-0def456789abc123  |  running | 54.x.x.x |
|  wiz-redteam       |  i-0789abc123def456  |  running | 52.x.x.x |
+--------------------+----------------------+----------+----------+

S3 Buckets:
2024-01-15 10:30:00 wiz-exercise-backups-abc123

EKS Cluster:
-------------------------------------------
|            DescribeCluster              |
+---------+--------+---------------------+
|  name   | status |      version        |
+---------+--------+---------------------+
|  wiz-eks|  ACTIVE|       1.28          |
+---------+--------+---------------------+
```

### 8. Run a Demo

Try the vulnerability demos:

```bash
# Show available demos
make demo

# Run S3 public bucket demo
make demo-s3

# SSH to MongoDB instance
make demo-ssh
```

### 9. Run Tests (Optional)

Validate the deployment and configuration:

```bash
# Check prerequisites
make check-prereqs

# Run all tests
make test

# Or run specific test suites
make test-terraform    # Validate Terraform
make test-security     # Run security scans
make test-docs         # Validate documentation
```

### 10. View Documentation

Serve documentation locally:

```bash
make docs
```

Opens documentation at `http://127.0.0.1:8000`

### 11. Clean Up

When done, destroy the infrastructure:

```bash
make destroy
```

Or for a complete reset:

```bash
make reset
```

## What's Next?

- [Prerequisites](prerequisites.md) - Detailed requirements
- [Configuration](configuration.md) - Environment variables reference
- [Architecture Overview](../architecture/overview.md) - Understand the system
- [Security Vulnerabilities](../security/overview.md) - Explore the intentional flaws
- [Attack Demos](../demos/overview.md) - Run attack scenarios
