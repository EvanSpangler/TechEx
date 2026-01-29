# Wiz Technical Exercise Requirements Checklist

This document tracks compliance with all mandatory and optional requirements from the Wiz Technical Exercise specification.

## Mandatory Requirements

### Virtual Machine Requirements

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Linux distribution 1+ year outdated | ✅ Met | Ubuntu 22.04 LTS with MongoDB 4.4 (EOL Feb 2024) |
| SSH exposed to the public | ✅ Met | Security group allows 0.0.0.0/0 on port 22 |
| Overprivileged CSP permissions | ✅ Met | IAM role has s3:*, ec2:Describe*, iam:Get/List*, secretsmanager:GetSecretValue |

**Location:** `terraform/modules/mongodb-vm/`

### MongoDB Requirements

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Version 1+ year outdated | ✅ Met | MongoDB 4.4.29 (EOL February 2024) |
| Access restricted to K8s nodes | ✅ Met | Security group restricts 27017 to VPC CIDR |
| Automated daily backups | ✅ Met | Cron job at 2 AM runs backup script |
| Backups to public S3 bucket | ✅ Met | Uploads to public bucket via AWS CLI |

**Location:** `terraform/modules/mongodb-vm/templates/mongodb-userdata.sh.tpl`

### Application Container Requirements

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Accessible via web browser | ✅ Met | ALB ingress exposes application on port 80/443 |
| Multi-container Kubernetes pods | ✅ Met | Deployment with multiple replicas on EKS |
| Contains wizexercise.txt file | ✅ Met | Created in Dockerfile with user's name |
| File contains user's full name | ✅ Met | "Evan Spangler - Wiz Technical Exercise 2024" |

**Location:** `app/Dockerfile`, `terraform/modules/k8s-app/`

### Container RBAC Requirements

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Cluster-admin role | ✅ Met | ClusterRoleBinding grants cluster-admin to tasky-sa |

**Location:** `terraform/modules/k8s-app/main.tf`

## Optional Requirements

### CI/CD Pipelines

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| IaC deployment pipeline | ✅ Met | GitHub Actions workflow `deploy-infra.yml` |
| Container build & push pipeline | ✅ Met | GitHub Actions workflow `build-deploy-app.yml` |

**Location:** `.github/workflows/`

### Pipeline Security

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| IaC security scanning | ✅ Met | tfsec and checkov in deploy workflow |
| Container security scanning | ✅ Met | Trivy and Grype in build workflow |
| wizexercise.txt verification | ✅ Met | Docker run command verifies file exists |

**Location:** `.github/workflows/build-deploy-app.yml`, `.github/workflows/test.yml`

### Audit Logging

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Control plane audit logging | ✅ Met | CloudTrail enabled with multi-region trail |
| CloudTrail logging | ✅ Met | S3 and management event logging |
| EKS audit logs | ✅ Met | Control plane logging enabled |

**Location:** `terraform/modules/security/main.tf`, `terraform/modules/eks/main.tf`

### Preventative Controls

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| AWS Config rules | ✅ Met | S3 public access, EC2 public IP, IAM root key checks |
| GuardDuty | ✅ Met | Enabled with S3, K8s, and malware protection |
| Security Hub | ✅ Met | CIS and AWS Foundational standards |

**Location:** `terraform/modules/security/main.tf`

### Detective Controls

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Wazuh SIEM | ✅ Met | Full Wazuh deployment with dashboard |
| CloudWatch monitoring | ✅ Met | VPC Flow Logs, EKS logs |
| Security Hub findings | ✅ Met | Aggregates findings from multiple sources |

**Location:** `terraform/modules/wazuh/`, `terraform/modules/security/`

## Testing & Validation

### Automated Testing

| Test Type | Status | Implementation |
|-----------|--------|----------------|
| Terraform validation | ✅ Met | `make test-terraform`, GitHub Actions |
| Terraform format check | ✅ Met | `terraform fmt -check` in CI |
| IaC security scanning | ✅ Met | tfsec, checkov, trivy |
| Container scanning | ✅ Met | Trivy, Grype |
| Kubernetes validation | ✅ Met | kubeconform, kubeaudit |
| Documentation build | ✅ Met | MkDocs strict build |

**Location:** `Makefile`, `.github/workflows/test.yml`

### Local Testing Commands

```bash
# Run all tests
make test

# Individual test suites
make test-terraform    # Terraform validation
make test-security     # Security scans (tfsec, checkov, trivy)
make test-lint         # Format and lint checks
make test-docs         # Documentation build
make test-container    # Container build and scan
make test-k8s          # Kubernetes manifest validation
make check-prereqs     # Verify prerequisites
```

## Documentation

### Required Documentation

| Document | Status | Location |
|----------|--------|----------|
| Architecture overview | ✅ Met | `docs/architecture/overview.md` |
| Deployment guide | ✅ Met | `docs/getting-started/quickstart.md` |
| Security vulnerabilities | ✅ Met | `docs/security/overview.md` |
| Demo procedures | ✅ Met | `docs/demos/` |
| API/Command reference | ✅ Met | `docs/reference/` |
| Troubleshooting | ✅ Met | `docs/troubleshooting/` |

## Vulnerability Summary

| ID | Vulnerability | Severity | Requirement |
|----|---------------|----------|-------------|
| WIZ-001 | Public S3 bucket | Critical | Mandatory (backup storage) |
| WIZ-002 | Overprivileged IAM | Critical | Mandatory (VM permissions) |
| WIZ-003 | Exposed SSH | High | Mandatory (SSH to public) |
| WIZ-004 | K8s cluster-admin | Critical | Mandatory (container RBAC) |
| WIZ-005 | Plaintext K8s secrets | High | Intentional for demo |
| WIZ-006 | Outdated MongoDB | Medium | Mandatory (1+ year old) |
| WIZ-007 | IMDSv1 enabled | High | Enables credential theft |

## Verification Commands

```bash
# Verify infrastructure deployed
make show

# Verify SSH access
make ssh-info

# Verify S3 public access
BUCKET=$(cd terraform && terraform output -raw backup_bucket_name)
aws s3 ls s3://$BUCKET --no-sign-request

# Verify K8s cluster-admin
kubectl auth can-i --list --as=system:serviceaccount:tasky:tasky-sa

# Verify MongoDB version (from MongoDB instance)
mongosh --eval "db.version()"

# Verify wizexercise.txt in container
docker run --rm <image> cat /app/wizexercise.txt
```

## Compliance Summary

| Category | Required | Implemented | Percentage |
|----------|----------|-------------|------------|
| Mandatory | 9 | 9 | 100% |
| Optional | 10 | 10 | 100% |
| **Total** | **19** | **19** | **100%** |

All requirements from the Wiz Technical Exercise V4 specification have been implemented.
