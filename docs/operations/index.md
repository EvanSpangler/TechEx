# Operations Guide

This section provides operational documentation for managing the Wiz Technical Exercise infrastructure.

## Overview

While this is an educational/demo environment, these operational procedures reflect real-world practices and serve as learning references for cloud infrastructure management.

## Quick Links

| Document | Description |
|----------|-------------|
| [Runbooks](runbooks.md) | Step-by-step operational procedures |
| [Disaster Recovery](disaster-recovery.md) | Recovery procedures and planning |
| [Costs Reference](../reference/costs.md) | Infrastructure cost breakdown |

## Key Operations

### Deployment

```bash
# Full deployment
make build

# Local deployment (no CI/CD)
make deploy-local

# View deployment status
make status
make show
```

### Access

```bash
# SSH to instances
make ssh-mongodb
make ssh-wazuh
make ssh-redteam

# Kubernetes access
aws eks update-kubeconfig --name wiz-exercise-eks
kubectl get pods -n tasky
```

### Monitoring

```bash
# Application health
curl http://<alb-dns>/health

# Pod status
kubectl get pods -A

# View logs
kubectl logs -n tasky deployment/tasky

# Wazuh dashboard (via SSH tunnel)
ssh -i keys/wazuh.pem -L 8443:localhost:443 ubuntu@<wazuh-ip>
# Then browse: https://localhost:8443
```

### Destruction

```bash
# Standard destroy
make destroy

# Force destroy (if stuck)
make force-destroy
```

## Environment Health Checklist

Daily/periodic verification:

- [ ] Application health endpoint responds
- [ ] All Kubernetes pods running
- [ ] MongoDB accessible
- [ ] Wazuh dashboard accessible
- [ ] No unexpected AWS billing alerts
- [ ] CloudTrail logging active
- [ ] GuardDuty enabled (if configured)

## Cost Management

**Estimated costs**: ~$8-10/day when running

**Best Practice**: Always destroy when not in use

```bash
# Check estimated running costs
make show  # Includes cost info

# Destroy to save costs
make destroy
```

See [Costs Reference](../reference/costs.md) for detailed breakdown.

## Incident Response Quick Reference

### Suspected Compromise

1. **Isolate**: Modify security groups to block traffic
2. **Preserve**: Create EBS snapshots for forensics
3. **Investigate**: Review CloudTrail, Wazuh alerts
4. **Recover**: Destroy and recreate if needed

See [Runbooks](runbooks.md) for detailed procedures.

### Common Issues

| Issue | Quick Fix |
|-------|-----------|
| Can't SSH | `make ssh-keys` to refresh keys |
| EKS unreachable | `aws eks update-kubeconfig ...` |
| High costs | `make destroy` when not in use |
| Deployment stuck | Check CloudFormation/Terraform state |

See [Troubleshooting](../troubleshooting/common-issues.md) for more.

## Related Documentation

- [Runbooks](runbooks.md) - Detailed operational procedures
- [Disaster Recovery](disaster-recovery.md) - Recovery planning
- [Troubleshooting](../troubleshooting/common-issues.md) - Problem resolution
- [Architecture Overview](../architecture/overview.md) - System design
