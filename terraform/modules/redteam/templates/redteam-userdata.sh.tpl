#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Red Team instance setup at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Configure SSH for public key only (keep UsePAM yes for Ubuntu compatibility)
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.d/pubkey-only.conf
systemctl restart sshd

# Install base tools
apt-get install -y \
  git curl wget jq unzip \
  nmap netcat-openbsd \
  python3 python3-pip python3-venv \
  dnsutils whois \
  tmux vim

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install mongosh
wget -qO- https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update
apt-get install -y mongodb-mongosh

# Create attack scripts directory
mkdir -p /opt/redteam/scripts
cd /opt/redteam

# Environment info
cat > /opt/redteam/env.sh << 'ENVFILE'
export ENVIRONMENT="${environment}"
export MONGODB_IP="${mongodb_ip}"
export EKS_CLUSTER="${eks_cluster}"
export BACKUP_BUCKET="${backup_bucket}"
export AWS_REGION="${aws_region}"
ENVFILE

# Make scripts directory accessible 
chmod 755 /opt/redteam/scripts

# Deploy attack chain script to /home/ubuntu via base64-encoded gzip
echo "${attack_chain_b64}" | base64 -d | gunzip > /home/ubuntu/attack-chain.sh
chown ubuntu:ubuntu /home/ubuntu/attack-chain.sh
chmod +x /home/ubuntu/attack-chain.sh

# Create README
cat > /opt/redteam/README.md << 'README'
# Wiz Exercise - Red Team Attack Chain

## Quick Start

Run the interactive attack chain demo:

```bash
./attack-chain.sh
```

The script walks through four phases:
1. **Reconnaissance** - Discover public S3 bucket via enumeration
2. **Exfiltration** - Download backups from public bucket
3. **Lateral Movement** - Extract SSH key, pivot to MongoDB VM
4. **Privilege Escalation** - IMDS credential theft on MongoDB VM

## Detection Points

Each phase includes detection points for:
- AWS GuardDuty
- CloudTrail
- Wazuh
- Security Hub
README

echo ""
echo "Red Team instance setup completed at $(date)"
echo ""
echo "Attack chain script: /home/ubuntu/attack-chain.sh"
echo "Run './attack-chain.sh' to start the demo"

%{ if enable_wazuh_agent && wazuh_manager_ip != "" ~}
# ==========================================
# Install Wazuh Agent
# ==========================================
echo "Installing Wazuh Agent at $(date)"

# Wait for Wazuh Manager to be ready (port 1514 for agent registration)
# The Manager takes 5-10 minutes to fully initialize after EC2 launch
WAZUH_MANAGER_IP="${wazuh_manager_ip}"
MAX_RETRIES=60
RETRY_INTERVAL=30
WAZUH_READY=false

echo "Waiting for Wazuh Manager at $WAZUH_MANAGER_IP to be ready..."

# Install netcat for port checking if not present
apt-get install -y netcat-openbsd || apt-get install -y netcat

for i in $(seq 1 $MAX_RETRIES); do
  # Check if Wazuh Manager registration port (1514) is listening
  if nc -z -w5 "$WAZUH_MANAGER_IP" 1514 2>/dev/null; then
    echo "Wazuh Manager is ready (attempt $i/$MAX_RETRIES)"
    WAZUH_READY=true
    break
  fi
  echo "Wazuh Manager not ready yet, waiting... (attempt $i/$MAX_RETRIES)"
  sleep $RETRY_INTERVAL
done

if [ "$WAZUH_READY" = "true" ]; then
  # Add Wazuh repository
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring \
    --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg

  echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    | tee /etc/apt/sources.list.d/wazuh.list

  apt-get update

  # Install Wazuh agent with manager IP and unique agent name
  # Use instance ID suffix to avoid duplicate name conflicts on instance rebuild
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null | tail -c 8 || date +%s | tail -c 8)
  WAZUH_MANAGER="$WAZUH_MANAGER_IP" WAZUH_AGENT_NAME="${environment}-redteam-$INSTANCE_ID" apt-get install -y wazuh-agent

  # Enable and start Wazuh agent
  systemctl daemon-reload
  systemctl enable wazuh-agent
  systemctl start wazuh-agent

  echo "Wazuh Agent installation completed at $(date)"
else
  echo "ERROR: Wazuh Manager did not become ready after $((MAX_RETRIES * RETRY_INTERVAL)) seconds"
  echo "Wazuh Agent installation skipped. Manual installation required."
fi
%{ endif ~}
