# Automated Testing

This project employs a comprehensive automated testing strategy to ensure the security, reliability, and correctness of the infrastructure and documentation. The testing suite is integrated into the `Makefile` and can be run locally or via GitHub Actions.

## Quick Start

To run all available tests:

```bash
make test
```

This is an alias for `make test-all`, which runs linting, terraform validation, security scans, and documentation checks.

## Test Suites

The testing framework is divided into several specialized suites targeting different aspects of the project.

### 1. Linting & Formatting (`make test-lint`)

Ensures code quality and consistent styling across different file types.

- **Terraform**: Runs `terraform fmt -check -recursive` to verify HCL formatting.
- **YAML**: Uses `yamllint` to check YAML syntax and style in `.github/`, `k8s/`, and `mkdocs.yml`.
- **Markdown**: Uses `markdownlint` to check documentation files in `docs/`.

### 2. Terraform Validation (`make test-terraform`)

Validates the syntactic correctness and internal consistency of Terraform configuration.

- **Command**: `terraform validate`
- **Scope**: Checks `terraform/` directory.
- **Purpose**: Ensures that the configuration is syntactically valid and internal references are correct.

### 3. Security Scanning (`make test-security`)

This is a critical component of the testing strategy, focusing on identifying vulnerabilities and misconfigurations in the infrastructure.

- **tfsec**: Static analysis for Terraform code to detect potential security issues.
- **checkov**: Infrastructure as Code (IaC) static analysis tool that scans Terraform and potential Kubernetes manifests.
- **trivy**: Scans the repository configuration for vulnerabilities.

> **Note**: For this specific "Wiz Technical Exercise" project, which is *deliberately* vulnerable, these scanners are expected to find issues. The build commands use `--soft-fail` or similar flags to ensure the pipeline reports findings without blocking the deployment of the intended vulnerable infrastructure.

### 4. Documentation Testing (`make test-docs`)

Ensures the documentation site builds correctly and contains no broken links.

- **MkDocs Build**: Runs `mkdocs build --strict` to ensure there are no warnings or errors during the site generation.
- **Link Checking**: Uses `linkchecker` to verify that all internal links in the generated `site/` directory are valid.

### 5. Kubernetes Validation (`make test-k8s`)

Validates Kubernetes manifests against the Kubernetes schema.

- **kubeval**: Validates that Kubernetes YAML files match the API schema.
- **kubeconform**: A stricter validation tool for Kubernetes manifests.

### 6. Container Testing (`make test-container`)

Builds and scans the application container image.

- **Build**: `docker build` to create the image.
- **Verification**: Checks for the existence of specific files (e.g., `wizexercise.txt`) inside the container.
- **Security**: Runs `trivy image` to scan the built image for OS and dependency vulnerabilities.

## CI/CD Integration

These tests are automatically executed in the GitHub Actions workflows defined in `.github/workflows/`. This ensures that every Pull Request and Push involves:

1.  **Static Analysis**: Linting and security scans.
2.  **Build Verification**: Validating that infrastructure code is deployable.
3.  **Documentation Checks**: Ensuring docs are up-to-date and unbroken.

See [CI/CD Integration](ci-integration.md) for detailed workflow documentation.

## Detailed Documentation

For more comprehensive information on each testing area, see the following guides:

| Guide | Description |
|-------|-------------|
| [Security Scanning](security-scanning.md) | In-depth coverage of tfsec, Checkov, Trivy, and Grype |
| [Validation Testing](validation.md) | Terraform and Kubernetes validation details |
| [Application Testing](application-tests.md) | Go application unit and integration tests |
| [CI/CD Integration](ci-integration.md) | GitHub Actions workflow integration |

## Related Documentation

- [Makefile Reference](../reference/makefile.md) - All test commands
- [GitHub Actions Reference](../reference/github-actions.md) - Workflow configurations
- [Local Development](../development/local-setup.md) - Running tests locally
