# Red Team Instance

Documentation for the pre-configured attack simulation instance.

## Overview

| Property | Value |
|----------|-------|
| Instance Type | t3.small |
| AMI | Ubuntu 22.04 LTS |
| Purpose | Attack simulation and testing |

## Pre-installed Tools

### Reconnaissance
- nmap
- dnsutils
- whois

### AWS Tools
- AWS CLI v2
- kubectl

### Database
- mongosh
- mongodb-clients

### General
- curl, wget, jq
- python3, pip
- tmux, vim

## Attack Scripts

Located at `/opt/redteam/scripts/`:

| Script | Purpose |
|--------|---------|
| `01-recon.sh` | Initial reconnaissance |
| `02-s3-exfil.sh` | S3 data exfiltration |
| `03-k8s-exploit.sh` | Kubernetes exploitation |
| `04-mongodb-access.sh` | Database access |
| `05-privesc.sh` | Privilege escalation |

### Usage

```bash
# SSH to instance
make ssh-redteam

# Load environment
source /opt/redteam/env.sh

# Run scripts
cd /opt/redteam/scripts
./01-recon.sh
```

## Access

```bash
make ssh-redteam
# or
ssh -i keys/redteam.pem ubuntu@<public-ip>
```

## Environment Variables

Set in `/opt/redteam/env.sh`:

- `ENVIRONMENT` - Deployment environment
- `MONGODB_IP` - MongoDB instance IP
- `EKS_CLUSTER` - EKS cluster name
- `BACKUP_BUCKET` - S3 bucket name
- `AWS_REGION` - AWS region

## Related Documentation

- [Demo: Attack Chain](../demos/attack-chain.md)
- [Demo: Overview](../demos/overview.md)
