# Frequently Asked Questions

## General Questions

### What is this project for?

This is a **security training exercise** that deploys intentionally vulnerable infrastructure to AWS. It's designed for:

- Red team penetration testing practice
- Blue team detection and response training
- Security architecture review demonstrations
- Cloud security awareness education

### Is this safe to deploy?

**Only in isolated environments.** This infrastructure has deliberate security vulnerabilities. Always:

- Use a dedicated AWS account
- Never deploy alongside production resources
- Destroy when not in use
- Don't store real sensitive data

### How much does it cost?

Estimated costs when running 24/7:

| Resource | Monthly Cost |
|----------|-------------|
| EKS Cluster | ~$73 |
| EC2 Instances (4) | ~$90 |
| NAT Gateway | ~$33 |
| ALB | ~$16 |
| **Total** | ~$200-250 |

**Tip:** Use `make destroy` when not actively using.

### How long does deployment take?

- **Full deployment**: 20-30 minutes (EKS cluster creation is slow)
- **Destroy**: 15-20 minutes
- **SSH key fetch**: < 1 minute

## Deployment Questions

### Can I deploy to a different region?

Yes:

```bash
# Via environment variable
export AWS_REGION=us-west-2
make build

# Or in .env
AWS_REGION=us-west-2
```

### Can I use an existing VPC?

The current design creates a new VPC. To use existing:

1. Modify `terraform/modules/networking/`
2. Import existing VPC as data source
3. Update references in other modules

### Why use GitHub Actions instead of local deployment?

Benefits of GitHub Actions:

- Consistent environment
- Audit trail of deployments
- No local credential exposure
- Easier team collaboration

Local deployment is available for development: `make deploy-local`

### Can I customize instance sizes?

Yes, edit `terraform/environments/demo.tfvars`:

```hcl
eks_node_instance_type = "t3.small"
mongodb_instance_type  = "t3.micro"
wazuh_instance_type    = "t3.small"
```

## Security Questions

### What vulnerabilities are intentionally deployed?

| ID | Vulnerability |
|----|---------------|
| WIZ-001 | Public S3 bucket |
| WIZ-002 | Overprivileged IAM role |
| WIZ-003 | SSH exposed to internet |
| WIZ-004 | K8s cluster-admin ServiceAccount |
| WIZ-005 | Secrets in plaintext |
| WIZ-006 | Outdated MongoDB version |
| WIZ-007 | IMDSv1 enabled |

See [Security Overview](../security/overview.md) for details.

### How do I fix the vulnerabilities?

Each vulnerability page includes remediation steps. For a secure deployment:

1. Enable S3 Block Public Access
2. Apply least privilege IAM
3. Restrict security groups
4. Use minimal RBAC
5. Use Secrets Manager
6. Upgrade MongoDB
7. Require IMDSv2

### Can attackers access my real AWS account?

The vulnerabilities are **scoped to this exercise**:

- S3 bucket only contains demo data
- IAM role is attached to exercise instances only
- EKS cluster is isolated

However, always use a dedicated AWS account to prevent any risk.

### Is the SSH exposure really dangerous?

Yes, but mitigated by:

- Public key authentication only (no passwords)
- Keys stored in SSM (not in code)

In production, SSH should never be exposed to 0.0.0.0/0.

## Technical Questions

### Why MongoDB 4.4 specifically?

MongoDB 4.4 is intentionally outdated (EOL February 2024) to demonstrate:

- Vulnerability scanning detection
- Risks of running outdated software
- Upgrade planning requirements

### How does the attack chain work?

```
Public S3 → Data exfiltration
     ↓
Exposed SSH → Instance access
     ↓
IMDS → Credential theft
     ↓
Overprivileged IAM → AWS enumeration
     ↓
EKS Access → Cluster-admin abuse
     ↓
K8s Secrets → Database credentials
     ↓
Full Compromise
```

### What monitoring is included?

- **Wazuh SIEM**: Host monitoring, log analysis
- **VPC Flow Logs**: Network traffic (via CloudWatch)
- **CloudTrail**: API audit trail
- **GuardDuty**: Threat detection (if enabled)

### Can I add my own detection rules?

Yes, in Wazuh:

```bash
make ssh-wazuh
sudo vim /var/ossec/etc/rules/local_rules.xml
sudo systemctl restart wazuh-manager
```

## Troubleshooting Questions

### Deployment fails with "AccessDenied"

Check IAM permissions. The deploying user needs broad permissions. See [Prerequisites](../getting-started/prerequisites.md).

### SSH keys not working

```bash
# Re-fetch keys
make ssh-keys

# Check permissions
chmod 600 keys/*.pem

# Verify correct instance IP
make ssh-info
```

### EKS cluster not accessible

```bash
# Update kubeconfig
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1

# Verify
kubectl cluster-info
```

### Makefile colors not showing

Ensure you're using a terminal that supports ANSI colors. The Makefile uses `printf` with escape sequences.

## Contributing Questions

### Can I contribute to this project?

Yes! Contributions welcome:

- Bug fixes
- Documentation improvements
- New vulnerability demonstrations
- Detection rule additions

### How do I report a security issue?

For issues with the exercise itself, open a GitHub issue.

For real security vulnerabilities in the code, please report privately.

### Can I use this for my own training?

Yes, this project is provided for educational purposes. Please:

- Give attribution
- Don't use for malicious purposes
- Only deploy in authorized environments

## Support

### Where can I get help?

1. Check [Troubleshooting](common-issues.md)
2. Search [GitHub Issues](https://github.com/evanspangler/wiz-technical-exercise/issues)
3. Review AWS and Terraform documentation
4. Open a new GitHub issue with details

### What information should I include in bug reports?

- Full error message
- Command that was run
- Output of `make show`
- Terraform version
- AWS region
- Steps to reproduce
