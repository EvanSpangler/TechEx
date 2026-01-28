# Terraform Issues

Troubleshooting Terraform-related problems.

## State Issues

### State Lock

```bash
# Force unlock
terraform force-unlock <lock-id>
```

### Backend Not Configured

```bash
# Initialize backend
make init
# or
terraform init -reconfigure
```

## Provider Issues

### Version Conflicts

```bash
# Clear and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

## Resource Issues

### Resource Already Exists

```bash
# Import existing resource
terraform import <resource> <id>
```

### Destroy Fails

```bash
# Try targeted destroy
terraform destroy -target=module.eks

# Force destroy (use with caution)
make force-destroy
```

## Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Check state
terraform state list
terraform state show <resource>
```
