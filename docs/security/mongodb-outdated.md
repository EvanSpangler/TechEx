# WIZ-006: Outdated MongoDB Version

## Overview

| Attribute | Value |
|-----------|-------|
| **ID** | WIZ-006 |
| **Severity** | Medium |
| **CVSS** | 6.5 |
| **Component** | MongoDB 4.4 |
| **MITRE ATT&CK** | T1190 - Exploit Public-Facing Application |

## Description

The MongoDB instance runs version 4.4, which reached end-of-life in February 2024. This version has known vulnerabilities and no longer receives security patches.

## Vulnerable Configuration

```bash
# terraform/modules/mongodb-vm/templates/mongodb-userdata.sh.tpl

# Add MongoDB 4.4 repository (INTENTIONALLY OUTDATED VERSION)
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-4.4.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# Install MongoDB 4.4
apt-get install -y mongodb-org=4.4.29 mongodb-org-server=4.4.29

# Pin version to prevent updates
echo "mongodb-org hold" | dpkg --set-selections
```

## Known Vulnerabilities

### CVEs in MongoDB 4.4

| CVE | Severity | Description |
|-----|----------|-------------|
| CVE-2024-1351 | High | Type confusion in BSON parsing |
| CVE-2023-1409 | Medium | Client certificate validation bypass |
| CVE-2022-24272 | Medium | Denial of service via malformed BSON |
| CVE-2021-32040 | High | Integer overflow in BSON |

### Version Comparison

| Version | Status | Support Until |
|---------|--------|---------------|
| 4.4 | **EOL** | Feb 2024 |
| 5.0 | EOL | Oct 2024 |
| 6.0 | Supported | Jul 2025 |
| 7.0 | Current | - |

## Exploitation

### Checking Version

```bash
# SSH to MongoDB instance
ssh -i keys/mongodb.pem ubuntu@<mongodb-ip>

# Check version
mongod --version
# db version v4.4.29

# Or via mongo shell
mongosh --eval "db.version()"
```

### Potential Exploits

While specific exploit code isn't provided (for safety), attack vectors include:

1. **BSON Parsing Bugs** - Craft malformed BSON to trigger memory corruption
2. **Authentication Bypass** - Exploit certificate validation issues
3. **DoS Attacks** - Send specially crafted queries to crash server

### Demo

```bash
# Check MongoDB version
make ssh-mongodb
mongod --version
```

## Impact

### Direct Risks
- Potential remote code execution
- Authentication bypass
- Denial of service
- Data corruption

### Compliance Impact
- Fails vulnerability scanning requirements
- Non-compliant with security baselines
- May violate regulatory requirements

## Detection

### AWS Inspector

Automatically detects outdated software:

```json
{
  "findingArn": "arn:aws:inspector2:...",
  "type": "PACKAGE_VULNERABILITY",
  "title": "CVE-2024-1351 - mongodb-org",
  "severity": "HIGH",
  "vulnerablePackages": [{
    "name": "mongodb-org",
    "version": "4.4.29",
    "fixedInVersion": "5.0.0"
  }]
}
```

### Wazuh Vulnerability Detection

```xml
<rule id="23502" level="10">
  <if_sid>23501</if_sid>
  <field name="vulnerability.package.name">mongodb</field>
  <field name="vulnerability.severity">High</field>
  <description>High severity MongoDB vulnerability detected</description>
</rule>
```

### Version Check Script

```bash
#!/bin/bash
# Check MongoDB version
MONGO_VERSION=$(mongod --version | grep "db version" | awk '{print $3}')
MAJOR_VERSION=$(echo $MONGO_VERSION | cut -d. -f1)
MINOR_VERSION=$(echo $MONGO_VERSION | cut -d. -f2)

if [ "$MAJOR_VERSION" -lt 6 ]; then
  echo "WARNING: MongoDB $MONGO_VERSION is outdated!"
  echo "Recommended: Upgrade to MongoDB 7.0"
  exit 1
fi
```

## Remediation

### Upgrade Process

1. **Backup data**
   ```bash
   mongodump --uri="mongodb://admin:password@localhost:27017" --out=/backup
   ```

2. **Stop MongoDB**
   ```bash
   sudo systemctl stop mongod
   ```

3. **Update repository**
   ```bash
   # Remove old repo
   sudo rm /etc/apt/sources.list.d/mongodb-org-4.4.list

   # Add MongoDB 7.0 repo
   curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
     sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

   echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
     sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
   ```

4. **Upgrade packages**
   ```bash
   sudo apt-get update
   sudo apt-get install -y mongodb-org
   ```

5. **Update configuration**
   ```yaml
   # /etc/mongod.conf - may need updates for new version
   storage:
     dbPath: /var/lib/mongodb
   net:
     port: 27017
     bindIp: 0.0.0.0
   security:
     authorization: enabled
   ```

6. **Start and verify**
   ```bash
   sudo systemctl start mongod
   mongod --version
   # Should show 7.0.x
   ```

### Terraform Update

```hcl
# Update userdata template
# Add MongoDB 7.0 repository
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
  gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update
apt-get install -y mongodb-org
```

### Use Managed Service

Consider Amazon DocumentDB (MongoDB-compatible):

```hcl
resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "tasky-docdb"
  engine                  = "docdb"
  master_username         = var.db_username
  master_password         = var.db_password
  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  skip_final_snapshot     = true

  vpc_security_group_ids = [aws_security_group.docdb.id]
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
}
```

Benefits:
- Automatic patching
- Managed backups
- High availability
- No version management

## Best Practices

1. **Automated patching** - Use AWS Systems Manager Patch Manager
2. **Version policy** - Never run EOL software
3. **Vulnerability scanning** - Regular Inspector scans
4. **Managed services** - Consider DocumentDB for production
5. **Update testing** - Test upgrades in staging first

## References

- [MongoDB Release Notes](https://www.mongodb.com/docs/manual/release-notes/)
- [MongoDB Security Advisories](https://www.mongodb.com/alerts)
- [AWS Inspector](https://docs.aws.amazon.com/inspector/)
- [MITRE ATT&CK T1190](https://attack.mitre.org/techniques/T1190/)
