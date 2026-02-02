# Validation Testing

This document covers validation testing for Terraform configurations, Kubernetes manifests, and other infrastructure code.

## Overview

Validation testing ensures that infrastructure code is syntactically correct, follows schema requirements, and passes basic consistency checks before deployment.

## Terraform Validation

### terraform validate

The primary validation command for Terraform configurations:

```bash
# Navigate to terraform directory
cd project/terraform

# Initialize (required before validate)
terraform init

# Run validation
terraform validate
```

**What it checks:**
- Syntax correctness
- Internal consistency
- Provider schema compliance
- Variable and output declarations
- Resource attribute validity

### terraform fmt

Ensures consistent formatting:

```bash
# Check formatting (dry run)
terraform fmt -check -recursive

# Auto-format files
terraform fmt -recursive

# Show diff of changes
terraform fmt -diff -recursive
```

### Running via Makefile

```bash
# Run all terraform validation
make test-terraform

# This runs:
# 1. terraform init (if needed)
# 2. terraform validate
# 3. terraform fmt -check
```

### Example Output

**Successful validation:**
```
Success! The configuration is valid.
```

**Validation error:**
```
Error: Invalid reference

  on modules/vpc/main.tf line 15, in resource "aws_subnet" "public":
  15:   vpc_id = aws_vpc.undefined.id

A managed resource "aws_vpc" "undefined" has not been declared in the root
module.
```

## Kubernetes Validation

### kubeval

Validates Kubernetes YAML against the API schema:

```bash
# Install kubeval
brew install kubeval  # macOS
# or
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz

# Validate manifests
kubeval k8s/*.yaml

# Validate with specific K8s version
kubeval --kubernetes-version 1.28.0 k8s/*.yaml

# Strict mode (fail on unknown fields)
kubeval --strict k8s/*.yaml
```

### kubeconform

A stricter alternative to kubeval with better performance:

```bash
# Install kubeconform
brew install kubeconform  # macOS
# or
go install github.com/yannh/kubeconform/cmd/kubeconform@latest

# Validate manifests
kubeconform k8s/*.yaml

# With specific K8s version
kubeconform -kubernetes-version 1.28.0 k8s/*.yaml

# With summary output
kubeconform -summary k8s/*.yaml
```

### Running via Makefile

```bash
# Run Kubernetes validation
make test-k8s

# This runs kubeval and/or kubeconform on k8s/ directory
```

### Example Output

**Successful validation:**
```
PASS - k8s/deployment.yaml contains a valid Deployment (tasky)
PASS - k8s/service.yaml contains a valid Service (tasky)
PASS - k8s/serviceaccount.yaml contains a valid ServiceAccount (tasky-admin)
```

**Validation error:**
```
FAIL - k8s/deployment.yaml: For field spec.template.spec.containers.0.ports.0.containerPort: Invalid type. Expected: integer, given: string
```

## YAML Validation

### yamllint

Validates YAML syntax and style:

```bash
# Install yamllint
pip install yamllint

# Lint all YAML files
yamllint .

# Lint specific directories
yamllint .github/ k8s/

# With custom config
yamllint -c .yamllint.yml .
```

### Configuration (.yamllint.yml)

```yaml
extends: default

rules:
  line-length:
    max: 120
    level: warning
  truthy:
    allowed-values: ['true', 'false', 'yes', 'no']
  comments:
    require-starting-space: true
    min-spaces-from-content: 1
  indentation:
    spaces: 2
    indent-sequences: true
```

### Running via Makefile

```bash
# Run YAML linting (part of test-lint)
make test-lint
```

## Markdown Validation

### markdownlint

Validates markdown files for style consistency:

```bash
# Install markdownlint-cli
npm install -g markdownlint-cli

# Lint all markdown files
markdownlint '**/*.md'

# Lint docs directory
markdownlint 'docs/**/*.md'

# Fix auto-fixable issues
markdownlint --fix 'docs/**/*.md'
```

### Configuration (.markdownlint.json)

```json
{
  "default": true,
  "MD013": {
    "line_length": 120
  },
  "MD033": {
    "allowed_elements": ["mermaid", "details", "summary"]
  },
  "MD041": false
}
```

## CI/CD Integration

Validation tests run automatically in the GitHub Actions test workflow:

```yaml
# .github/workflows/test.yml (excerpt)
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform -chdir=terraform init -backend=false

      - name: Terraform Validate
        run: terraform -chdir=terraform validate

      - name: Terraform Format Check
        run: terraform -chdir=terraform fmt -check -recursive

      - name: Validate Kubernetes manifests
        run: |
          curl -sL https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
          ./kubeconform -summary k8s/
```

## Pre-commit Hooks

Automate validation before commits:

### Setup

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install
```

### Configuration (.pre-commit-config.yaml)

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tfsec

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.32.0
    hooks:
      - id: yamllint
        args: [-c=.yamllint.yml]

  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.37.0
    hooks:
      - id: markdownlint
        args: [--fix]
```

## Validation Checklist

Before deploying, ensure:

- [ ] `terraform validate` passes
- [ ] `terraform fmt -check` shows no changes needed
- [ ] Kubernetes manifests validate against target K8s version
- [ ] YAML files pass yamllint
- [ ] Markdown files pass markdownlint
- [ ] All security scans complete (see [Security Scanning](security-scanning.md))

## Troubleshooting

### "Backend not initialized"

```bash
# Run init before validate
terraform init -backend=false  # Skip backend for validation only
terraform validate
```

### "Provider not found"

```bash
# Ensure providers are downloaded
terraform init
terraform validate
```

### "Unknown Kubernetes resource type"

```bash
# Update kubeconform schemas
kubeconform -schema-location default k8s/

# Or use specific version
kubeconform -kubernetes-version 1.28.0 k8s/
```

## Related Documentation

- [Testing Overview](index.md)
- [Security Scanning](security-scanning.md)
- [CI Integration](ci-integration.md)
- [Terraform Reference](../reference/terraform.md)
