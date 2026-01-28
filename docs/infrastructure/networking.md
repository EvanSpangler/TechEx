# Networking

Documentation for VPC and network configuration.

## VPC Overview

| Property | Value |
|----------|-------|
| CIDR | 10.0.0.0/16 |
| Region | us-east-1 |
| AZs | us-east-1a, us-east-1b |

## Subnets

| Subnet | CIDR | Type | AZ |
|--------|------|------|-----|
| Public A | 10.0.1.0/24 | Public | us-east-1a |
| Public B | 10.0.2.0/24 | Public | us-east-1b |
| Private A | 10.0.10.0/24 | Private | us-east-1a |
| Private B | 10.0.11.0/24 | Private | us-east-1b |

## Resources

- **Internet Gateway**: Public internet access
- **NAT Gateway**: Private subnet outbound access
- **Route Tables**: Public and private routing

## Security Groups

See [Architecture: Network Topology](../architecture/network.md) for security group rules.

## Related Documentation

- [Architecture: Network Topology](../architecture/network.md)
- [Security: Exposed SSH](../security/ssh-exposed.md)
