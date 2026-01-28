# Wiz Technical Exercise

A deliberately vulnerable two-tier web application demonstrating cloud security misconfigurations and their detection.

**Candidate:** Evan Spangler

## Architecture

```
Internet → ALB → EKS (Private Subnet) → MongoDB VM (Public Subnet) → S3 Backup (Public)
                                              ↑
                                        SSH:22 Open
```

### Components

- **Web Application**: Go-based todo app (tasky) running on EKS
- **Database**: MongoDB 4.4 on Ubuntu 20.04 VM
- **Storage**: S3 bucket for database backups
- **Security Monitoring**: CloudTrail, GuardDuty, Security Hub, Wazuh
- **Red Team**: Instance with attack scripts for demonstration

## Intentional Vulnerabilities

| Component | Vulnerability | Impact |
|-----------|---------------|--------|
| MongoDB VM | SSH exposed to 0.0.0.0/0 | Initial access |
| MongoDB VM | Ubuntu 20.04 (outdated) | Known CVEs |
| MongoDB VM | MongoDB 4.4 (outdated) | Known CVEs |
| MongoDB VM | IAM role with ec2:* | Privilege escalation |
| MongoDB VM | IMDSv1 enabled | Credential theft |
| S3 Bucket | Public read/list | Data exfiltration |
| Kubernetes | cluster-admin ServiceAccount | Lateral movement |
| Kubernetes | Secrets in environment vars | Credential exposure |

## Prerequisites

- AWS Account with CloudLabs voucher
- AWS CLI configured
- Terraform >= 1.0
- kubectl
- Docker

## Quick Start

```bash
# Clone repository
git clone <repo-url>
cd wiz-exercise

# Set environment variables
export TF_VAR_mongodb_admin_pass="<secure-password>"
export TF_VAR_mongodb_app_pass="<secure-password>"
export TF_VAR_redteam_allowed_cidrs='["YOUR_IP/32"]'

# Initialize Terraform
cd terraform
terraform init

# Deploy
terraform apply -var-file="environments/demo.tfvars"

# Configure kubectl
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1

# Build and push app (after ECR is created)
cd ../app
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker build -t wiz-exercise-todo .
docker tag wiz-exercise-todo:latest <account>.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-todo:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-todo:latest
```

## Demo Attack Chain

1. **Reconnaissance**: Enumerate public S3 bucket
2. **Data Exfiltration**: Download database backups
3. **K8s Exploitation**: Extract secrets using cluster-admin
4. **Database Access**: Connect with stolen credentials
5. **Privilege Escalation**: IMDS credential theft on MongoDB VM
6. **Lateral Movement**: Use stolen IAM credentials

## Detection Points

- **GuardDuty**: Unusual S3 access, IAM credential abuse, EKS anomalies
- **CloudTrail**: All API calls logged
- **Security Hub**: CIS benchmark findings
- **Wazuh**: SSH monitoring, file integrity, command execution

## Cleanup

```bash
cd terraform
terraform destroy -var-file="environments/demo.tfvars"
```

**Important**: Always destroy resources after demo to avoid charges (~$9.50/day).

## Project Structure

```
wiz-exercise/
├── .github/workflows/
│   ├── deploy-infra.yml      # Terraform CI/CD
│   └── build-deploy-app.yml  # App CI/CD
├── app/                      # Go todo application
├── terraform/
│   ├── main.tf               # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── environments/
│   │   └── demo.tfvars
│   └── modules/
│       ├── vpc/
│       ├── mongodb-vm/
│       ├── s3-backup/
│       ├── eks/
│       ├── k8s-app/
│       ├── security/
│       ├── wazuh/
│       └── redteam/
└── README.md
```

## License

MIT
