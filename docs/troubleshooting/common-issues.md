# Common Issues

Solutions to frequently encountered problems with the Wiz Technical Exercise.

## Deployment Issues

### Terraform State Lock

**Error:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Path:      wiz-exercise-tfstate/terraform.tfstate
```

**Solution:**
```bash
# Force unlock (use with caution)
cd terraform
terraform force-unlock xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

### Backend Not Initialized

**Error:**
```
Error: Backend initialization required, please run "terraform init"
```

**Solution:**
```bash
make init
# or
cd terraform && terraform init -reconfigure
```

---

### AWS Credentials Not Found

**Error:**
```
Error: No valid credential sources found
```

**Solutions:**

1. Check `.env` file exists and has correct format:
   ```bash
   cat .env
   # Should show AWS_ACCESS_KEY_ID=... (no quotes!)
   ```

2. Source environment:
   ```bash
   source .env
   aws sts get-caller-identity
   ```

3. Check for quotes in `.env`:
   ```bash
   # Wrong:
   AWS_ACCESS_KEY_ID="AKIA..."

   # Correct:
   AWS_ACCESS_KEY_ID=AKIA...
   ```

---

### EKS Cluster Creation Timeout

**Error:**
```
Error: waiting for EKS Cluster (wiz-exercise-eks) to create: timeout while waiting for state
```

**Solution:**

EKS clusters take 15-20 minutes. If truly stuck:

```bash
# Check cluster status
aws eks describe-cluster --name wiz-exercise-eks --query 'cluster.status'

# If FAILED, check CloudWatch logs
aws logs filter-log-events --log-group-name /aws/eks/wiz-exercise-eks/cluster
```

---

### Insufficient IAM Permissions

**Error:**
```
Error: AccessDenied: User is not authorized to perform: eks:CreateCluster
```

**Solution:**

Ensure IAM user has required permissions. See [Prerequisites](../getting-started/prerequisites.md).

---

### VPC Quota Exceeded

**Error:**
```
Error: VpcLimitExceeded: The maximum number of VPCs has been reached.
```

**Solution:**
```bash
# Check current VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].VpcId'

# Delete unused VPCs or request quota increase
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10
```

## SSH Issues

### Permission Denied

**Error:**
```
Permission denied (publickey).
```

**Solutions:**

1. Check key permissions:
   ```bash
   chmod 600 keys/*.pem
   ```

2. Verify correct key:
   ```bash
   make ssh-info  # Shows which key for which instance
   ```

3. Re-fetch keys:
   ```bash
   make ssh-keys
   ```

---

### Connection Refused

**Error:**
```
ssh: connect to host x.x.x.x port 22: Connection refused
```

**Solutions:**

1. Verify instance is running:
   ```bash
   make show
   ```

2. Check security group allows SSH:
   ```bash
   aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*mongodb*"
   ```

3. Wait for instance initialization:
   ```bash
   # Check instance status
   aws ec2 describe-instance-status --instance-id <id>
   ```

---

### Host Key Verification Failed

**Error:**
```
Host key verification failed.
```

**Solution:**
```bash
# Remove old key
ssh-keygen -R <ip-address>

# Or connect with strict checking disabled (already in Makefile)
ssh -o StrictHostKeyChecking=no -i keys/mongodb.pem ubuntu@<ip>
```

## Kubernetes Issues

### kubectl Connection Refused

**Error:**
```
Unable to connect to the server: dial tcp: connection refused
```

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1

# Verify
kubectl cluster-info
```

---

### Unauthorized Access

**Error:**
```
error: You must be logged in to the server (Unauthorized)
```

**Solutions:**

1. Refresh credentials:
   ```bash
   aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1
   ```

2. Check IAM permissions:
   ```bash
   aws sts get-caller-identity
   ```

3. Verify cluster exists:
   ```bash
   aws eks describe-cluster --name wiz-exercise-eks
   ```

---

### Pods Not Starting

**Error:**
```
NAME    READY   STATUS             RESTARTS   AGE
tasky   0/1     ImagePullBackOff   0          5m
```

**Solution:**
```bash
# Check events
kubectl describe pod -n tasky <pod-name>

# Check if ECR access is configured
kubectl get serviceaccount -n tasky -o yaml
```

## GitHub Actions Issues

### Workflow Not Triggering

**Problem:** `make build` doesn't start workflow

**Solutions:**

1. Check GitHub CLI auth:
   ```bash
   gh auth status
   ```

2. Verify workflow exists:
   ```bash
   gh workflow list
   ```

3. Check Actions is enabled in repo settings

---

### Secrets Not Found

**Error:**
```
Error: Input required and not supplied: aws-access-key-id
```

**Solution:**
```bash
# Re-configure secrets
make secrets

# Verify secrets exist
gh secret list
```

---

### Workflow Fails on Apply

Check workflow logs:
```bash
make logs
```

Common causes:

- AWS credential issues
- Terraform state lock
- Resource quota exceeded

## Makefile Issues

### Command Not Found

**Error:**
```
make: aws: Command not found
```

**Solution:**

Install missing tools. See [Prerequisites](../getting-started/prerequisites.md).

---

### Colors Not Displaying

**Problem:** Output shows escape codes like `\033[0;32m`

**Solution:**

This was fixed by using `printf` instead of `echo`. Update Makefile:

```makefile
# Use printf for colors
@printf "$(GREEN)Message$(NC)\n"
```

---

### Environment Variables Not Loading

**Problem:** AWS commands fail in make but work in shell

**Solution:**

Check `.env` format:
```bash
# Must NOT have quotes
AWS_ACCESS_KEY_ID=AKIA...

# NOT
AWS_ACCESS_KEY_ID="AKIA..."
```

## AWS Service Issues

### GuardDuty Not Detecting

**Problem:** Attacks don't generate GuardDuty findings

**Solutions:**

1. Enable GuardDuty:
   ```bash
   aws guardduty create-detector --enable
   ```

2. Check detector status:
   ```bash
   aws guardduty list-detectors
   aws guardduty get-detector --detector-id <id>
   ```

3. Some findings take 15-30 minutes to appear

---

### S3 Access Denied

**Error:**
```
An error occurred (AccessDenied) when calling the ListObjectsV2 operation
```

**For intentionally public bucket:**
```bash
# Verify public access
aws s3 ls s3://bucket-name --no-sign-request
```

**For private access:**
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket bucket-name
```

## Performance Issues

### Deployment Too Slow

EKS cluster creation takes 15-20 minutes. Speed up development:

```bash
# Use plan to preview changes
make plan

# Only apply specific modules
cd terraform
terraform apply -target=module.networking
```

### High AWS Costs

```bash
# Destroy when not in use
make destroy

# Use smaller instances in tfvars
eks_node_instance_type = "t3.small"
mongodb_instance_type = "t3.micro"
```

## Getting Help

If issues persist:

1. Check existing [GitHub Issues](https://github.com/evanspangler/wiz-technical-exercise/issues)
2. Review [AWS Documentation](https://docs.aws.amazon.com/)
3. Search [Terraform Registry](https://registry.terraform.io/)

When reporting issues, include:

- Error message (full output)
- Command that failed
- Output of `make show`
- Terraform version (`terraform --version`)
- AWS region
