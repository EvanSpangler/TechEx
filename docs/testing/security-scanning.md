# Security Scanning

This document details the security scanning tools integrated into the Wiz Technical Exercise project. These scans identify vulnerabilities in infrastructure code, container images, and configurations.

> **Note**: This project is *deliberately* vulnerable for educational purposes. Security scans are configured with `--soft-fail` to report findings without blocking deployment.

## Scanning Tools Overview

| Tool | Target | Type | Integration |
|------|--------|------|-------------|
| [tfsec](https://aquasecurity.github.io/tfsec/) | Terraform code | Static analysis | CI/CD + Local |
| [Checkov](https://www.checkov.io/) | IaC (Terraform, K8s) | Policy-as-code | CI/CD + Local |
| [Trivy](https://trivy.dev/) | Container images, repos | Vulnerability scanner | CI/CD + Local |
| [Grype](https://github.com/anchore/grype) | Container images | Vulnerability scanner | CI/CD |

## Running Security Scans

### Quick Start

```bash
# Run all security scans
make test-security

# Run specific scanners
tfsec terraform/
checkov -d terraform/
trivy fs .
```

### Detailed Commands

#### tfsec - Terraform Security Scanner

```bash
# Basic scan
tfsec terraform/

# With severity threshold
tfsec terraform/ --minimum-severity HIGH

# Generate SARIF report for GitHub
tfsec terraform/ --format sarif --out tfsec-results.sarif

# Exclude specific checks (for intentional vulnerabilities)
tfsec terraform/ --exclude-downloaded-modules
```

**Common Findings in This Project:**

| Check ID | Description | Status |
|----------|-------------|--------|
| AWS002 | S3 bucket without logging | Intentional |
| AWS017 | S3 bucket with public access | Intentional (WIZ-001) |
| AWS050 | IAM policy too permissive | Intentional (WIZ-002) |
| AWS018 | Security group allows 0.0.0.0/0 | Intentional (WIZ-003) |

#### Checkov - Policy-as-Code Scanner

```bash
# Scan Terraform directory
checkov -d terraform/

# Scan specific file
checkov -f terraform/main.tf

# Output as JSON
checkov -d terraform/ -o json > checkov-results.json

# Skip specific checks
checkov -d terraform/ --skip-check CKV_AWS_18,CKV_AWS_19

# Scan Kubernetes manifests
checkov -d k8s/ --framework kubernetes
```

**Common Findings:**

| Check ID | Description | Severity |
|----------|-------------|----------|
| CKV_AWS_18 | S3 access logging disabled | Low |
| CKV_AWS_19 | S3 bucket encryption disabled | Medium |
| CKV_AWS_20 | S3 bucket has public access | Critical |
| CKV_AWS_23 | Security group allows all traffic | High |
| CKV_AWS_79 | IMDSv2 not required | High |

#### Trivy - Vulnerability Scanner

```bash
# Scan repository for misconfigurations
trivy fs .

# Scan container image
trivy image tasky:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL tasky:latest

# Generate JSON report
trivy image -f json -o trivy-results.json tasky:latest

# Scan for secrets
trivy fs --scanners secret .
```

**Container Image Scan Example Output:**

```
tasky:latest (alpine 3.18)
==========================
Total: 0 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)

Go (gobinary)
=============
Total: 2 (UNKNOWN: 0, LOW: 0, MEDIUM: 1, HIGH: 1, CRITICAL: 0)

+-------------------+------------------+----------+
|      LIBRARY      |  VULNERABILITY   | SEVERITY |
+-------------------+------------------+----------+
| golang.org/x/text | CVE-2022-XXXXX   | HIGH     |
| github.com/gin    | CVE-2023-XXXXX   | MEDIUM   |
+-------------------+------------------+----------+
```

#### Grype - Image Vulnerability Scanner

```bash
# Scan container image
grype tasky:latest

# Scan with severity threshold
grype tasky:latest --fail-on high

# Output as JSON
grype tasky:latest -o json > grype-results.json

# Scan from registry
grype registry:ghcr.io/evanspangler/tasky:latest
```

## CI/CD Integration

Security scans run automatically in GitHub Actions workflows.

### Infrastructure Pipeline

```yaml
# .github/workflows/deploy-infra.yml (excerpt)
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    working_directory: terraform/
    soft_fail: true  # Don't block on findings

- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    soft_fail: true
```

### Application Pipeline

```yaml
# .github/workflows/build-deploy-app.yml (excerpt)
- name: Scan with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_TAG }}
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Scan with Grype
  uses: anchore/scan-action@v3
  with:
    image: ${{ env.IMAGE_TAG }}
    fail-build: false
```

## Interpreting Results

### Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| CRITICAL | Exploitable with severe impact | Immediate remediation (normally) |
| HIGH | Significant security risk | Prioritize fix |
| MEDIUM | Moderate risk | Plan remediation |
| LOW | Minor security concern | Address as time permits |
| UNKNOWN | Insufficient data | Investigate |

### Expected Findings

This project intentionally contains vulnerabilities. Expected findings include:

| Finding | Vulnerability ID | Why It's Intentional |
|---------|------------------|---------------------|
| Public S3 bucket | WIZ-001 | Demo data exfiltration |
| Overprivileged IAM | WIZ-002 | Demo privilege escalation |
| Open SSH port | WIZ-003 | Demo initial access |
| Cluster-admin SA | WIZ-004 | Demo K8s exploitation |
| Secrets in env vars | WIZ-005 | Demo secret exposure |
| Outdated MongoDB | WIZ-006 | Demo vulnerable software |
| IMDSv1 enabled | WIZ-007 | Demo IMDS exploitation |

## Suppressing Findings

For intentional vulnerabilities, you can suppress specific findings:

### tfsec Inline Suppression

```hcl
resource "aws_s3_bucket" "backup" {
  bucket = "wiz-exercise-backup"
  #tfsec:ignore:aws-s3-enable-bucket-logging
  #tfsec:ignore:aws-s3-block-public-acls
}
```

### Checkov Inline Suppression

```hcl
resource "aws_s3_bucket" "backup" {
  #checkov:skip=CKV_AWS_18:Intentionally public for demo
  bucket = "wiz-exercise-backup"
}
```

### Trivy .trivyignore

```
# .trivyignore
CVE-2023-XXXXX  # Accepted risk for demo
CVE-2024-XXXXX  # Will fix in next release
```

## Adding Custom Policies

### Checkov Custom Policy

```python
# custom_policies/check_wiz_tag.py
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckResult, CheckCategories

class WizTagRequired(BaseResourceCheck):
    def __init__(self):
        name = "Ensure all resources have wiz-exercise tag"
        id = "CKV_WIZ_001"
        supported_resources = ['*']
        categories = [CheckCategories.CONVENTION]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        tags = conf.get('tags', [{}])[0]
        if tags.get('project') == 'wiz-exercise':
            return CheckResult.PASSED
        return CheckResult.FAILED

check = WizTagRequired()
```

## Best Practices

1. **Run scans locally before pushing** - Catch issues early
2. **Review all findings** - Even in a vulnerable-by-design project
3. **Document suppressions** - Explain why each suppression exists
4. **Update tools regularly** - Security databases update frequently
5. **Monitor for new CVEs** - New vulnerabilities may affect dependencies

## Related Documentation

- [Testing Overview](index.md)
- [CI Integration](ci-integration.md)
- [Validation Testing](validation.md)
- [Security Overview](../security/overview.md)
