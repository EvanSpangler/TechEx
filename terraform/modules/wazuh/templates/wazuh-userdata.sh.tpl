#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Wazuh Manager setup at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Configure SSH for public key only
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.d/pubkey-only.conf
systemctl restart sshd

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker
systemctl enable docker
systemctl start docker

# Create Wazuh directory
mkdir -p /opt/wazuh
cd /opt/wazuh

# Clone Wazuh Docker repository
git clone https://github.com/wazuh/wazuh-docker.git -b v4.7.0

cd wazuh-docker/single-node

# Generate certificates
docker compose -f generate-indexer-certs.yml run --rm generator

# Set admin password
sed -i "s/INDEXER_PASSWORD=.*/INDEXER_PASSWORD=${wazuh_admin_pass}/" .env
sed -i "s/DASHBOARD_PASSWORD=.*/DASHBOARD_PASSWORD=${wazuh_admin_pass}/" .env
sed -i "s/API_PASSWORD=.*/API_PASSWORD=${wazuh_api_pass}/" .env

# Start Wazuh stack
docker compose up -d

# Wait for Wazuh to be ready
echo "Waiting for Wazuh to start..."
sleep 120

# Create agent enrollment script
cat > /opt/wazuh/enroll-agent.sh << 'ENROLL'
#!/bin/bash
# Agent enrollment script
# Usage: ./enroll-agent.sh <agent_name> <agent_ip>

AGENT_NAME=$1
AGENT_IP=$2
WAZUH_MANAGER_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Enrolling agent: $AGENT_NAME ($AGENT_IP)"
echo "Wazuh Manager: $WAZUH_MANAGER_IP"

# Get auth token
TOKEN=$(curl -s -u wazuh-wui:${wazuh_api_pass} -k -X POST "https://localhost:55000/security/user/authenticate?raw=true")

# Register agent
curl -s -k -X POST "https://localhost:55000/agents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$AGENT_NAME\",\"ip\":\"$AGENT_IP\"}"

echo ""
echo "Agent enrolled. Install agent on target machine:"
echo "curl -s https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.0-1_amd64.deb -o wazuh-agent.deb"
echo "sudo WAZUH_MANAGER='$WAZUH_MANAGER_IP' dpkg -i wazuh-agent.deb"
echo "sudo systemctl enable wazuh-agent && sudo systemctl start wazuh-agent"
ENROLL

chmod +x /opt/wazuh/enroll-agent.sh

# Create status check script
cat > /opt/wazuh/status.sh << 'STATUS'
#!/bin/bash
echo "=== Wazuh Stack Status ==="
cd /opt/wazuh/wazuh-docker/single-node
docker compose ps

echo ""
echo "=== Wazuh Manager Info ==="
curl -s -k -u wazuh-wui:${wazuh_api_pass} "https://localhost:55000/manager/info" | jq .

echo ""
echo "=== Connected Agents ==="
TOKEN=$(curl -s -u wazuh-wui:${wazuh_api_pass} -k -X POST "https://localhost:55000/security/user/authenticate?raw=true")
curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/agents?pretty=true" | jq '.data.affected_items[] | {id, name, ip, status}'
STATUS

chmod +x /opt/wazuh/status.sh

echo "Wazuh Manager setup completed at $(date)"
echo ""
echo "Dashboard URL: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Username: admin"
echo "Password: ${wazuh_admin_pass}"
