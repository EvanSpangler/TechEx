# IAM Roles

Documentation for IAM role configuration.

## MongoDB Instance Role

| Property | Value |
|----------|-------|
| Role Name | `mongodb-role` |
| Attached To | MongoDB EC2 instance |
| Permissions | **Overprivileged** (intentional) |

### Permissions (Vulnerable)

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:Describe*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["iam:Get*", "iam:List*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "*"
    }
  ]
}
```

See [WIZ-002: Overprivileged IAM](../security/iam-overprivileged.md) for details.

## EKS Roles

### Cluster Role
Standard EKS cluster role with managed policies.

### Node Role
Standard EKS node role with managed policies.

## Wazuh Instance Role

Minimal permissions for CloudWatch logs.

## Related Documentation

- [Security: Overprivileged IAM](../security/iam-overprivileged.md)
- [Security: IMDS Exploitation](../security/imds.md)
