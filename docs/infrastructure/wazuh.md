# Wazuh SIEM

Documentation for the Wazuh security monitoring instance.

## Overview

| Property | Value |
|----------|-------|
| Instance Type | t3.medium |
| AMI | Ubuntu 22.04 LTS |
| Wazuh Version | 4.7.0 |
| Deployment | Docker (single-node) |

## Components

- **Wazuh Manager**: Central management and analysis
- **Wazuh Indexer**: Elasticsearch-based data store
- **Wazuh Dashboard**: Kibana-based web interface

## Access

### Dashboard

```bash
make demo-wazuh
# Opens https://<wazuh-ip> in browser

# Credentials:
# Username: admin
# Password: <WAZUH_ADMIN_PASS from .env>
```

### SSH

```bash
make ssh-wazuh
```

## Configuration

The instance runs Wazuh via Docker Compose at `/opt/wazuh/wazuh-docker/single-node/`.

### Management Commands

```bash
# Check status
cd /opt/wazuh/wazuh-docker/single-node
docker compose ps

# View logs
docker compose logs -f wazuh.manager

# Restart
docker compose restart
```

## Agent Enrollment

### Enroll New Agent

```bash
# On Wazuh server
/opt/wazuh/enroll-agent.sh <agent-name> <agent-ip>
```

### Install Agent on Target

```bash
curl -s https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.0-1_amd64.deb -o wazuh-agent.deb
sudo WAZUH_MANAGER='<wazuh-ip>' dpkg -i wazuh-agent.deb
sudo systemctl enable wazuh-agent && sudo systemctl start wazuh-agent
```

## Detection Capabilities

- SSH authentication monitoring
- File integrity monitoring
- Log analysis
- AWS CloudTrail integration
- Vulnerability detection

## Related Documentation

- [Demo: Detection & Response](../demos/detection.md)
