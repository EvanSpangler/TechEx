# GitHub Actions

Reference for the CI/CD workflow.

## Workflow File

Located at: `.github/workflows/deploy.yml`

## Triggers

- **Manual dispatch** with action parameter
- Options: `plan`, `apply`, `destroy`

## Usage

```bash
# Deploy infrastructure
make build
# or
gh workflow run "Deploy Infrastructure" --field action=apply

# Destroy infrastructure
make destroy
# or
gh workflow run "Deploy Infrastructure" --field action=destroy

# Plan only
gh workflow run "Deploy Infrastructure" --field action=plan
```

## Required Secrets

Configure in GitHub Settings → Secrets:

| Secret | Required |
|--------|----------|
| `AWS_ACCESS_KEY_ID` | Yes |
| `AWS_SECRET_ACCESS_KEY` | Yes |
| `MONGODB_ADMIN_PASS` | Yes |
| `MONGODB_APP_PASS` | Yes |
| `BACKUP_ENCRYPTION_KEY` | No |
| `WAZUH_ADMIN_PASS` | No |
| `WAZUH_API_PASS` | No |

## Monitoring

```bash
# Watch running workflow
make watch

# View logs
make logs

# Check status
make status
```
