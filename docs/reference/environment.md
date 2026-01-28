# Environment Variables

Reference for all environment variables.

## Required Variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `MONGODB_ADMIN_PASS` | MongoDB admin password |
| `MONGODB_APP_PASS` | MongoDB app user password |

## Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `BACKUP_ENCRYPTION_KEY` | (generated) | Backup encryption key |
| `WAZUH_ADMIN_PASS` | (generated) | Wazuh dashboard password |
| `WAZUH_API_PASS` | (generated) | Wazuh API password |

## File Format

Create `.env` file (no quotes around values):

```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
MONGODB_ADMIN_PASS=SecurePassword123
MONGODB_APP_PASS=AppPassword456
```

!!! warning "No Quotes"
    Do not use quotes around values when using with Make:
    ```bash
    # Correct
    AWS_ACCESS_KEY_ID=AKIA...

    # Incorrect
    AWS_ACCESS_KEY_ID="AKIA..."
    ```
