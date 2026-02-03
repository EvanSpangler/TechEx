#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Wazuh Manager setup at $(date)"

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

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release jq

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

# Set passwords in docker-compose.yml (v4.7.0 has passwords hardcoded in compose file, not .env)
# Escape special characters in passwords for sed
ESCAPED_ADMIN_PASS=$(printf '%s\n' "${wazuh_admin_pass}" | sed 's/[&/\]/\\&/g')
ESCAPED_API_PASS=$(printf '%s\n' "${wazuh_api_pass}" | sed 's/[&/\]/\\&/g')

# Replace INDEXER_PASSWORD (used by dashboard)
sed -i "s/INDEXER_PASSWORD=SecretPassword/INDEXER_PASSWORD=$ESCAPED_ADMIN_PASS/g" docker-compose.yml

# Replace API_PASSWORD - the default has special chars: MyS3cr37P450r.*-
# The . and * need to be escaped in the regex pattern
sed -i "s/API_PASSWORD=MyS3cr37P450r\\.\\*-/API_PASSWORD=$ESCAPED_API_PASS/g" docker-compose.yml

# Verify the replacements worked
echo "=== Verifying password configuration ==="
grep -E "(INDEXER_PASSWORD|API_PASSWORD)" docker-compose.yml | head -4

# Start Wazuh stack
docker compose up -d

# Wait for Wazuh to be ready
echo "Waiting for Wazuh to start..."
sleep 120

# Store API password for helper scripts
echo "${wazuh_api_pass}" > /opt/wazuh/.api_pass
chmod 600 /opt/wazuh/.api_pass

# Update Dashboard's API configuration with the correct password
# The Dashboard stores API connection settings in wazuh.yml
echo "=== Updating Dashboard API configuration ==="
DASHBOARD_CONTAINER="single-node-wazuh.dashboard-1"
WAZUH_YML_PATH="/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"

# Wait for the dashboard config file to exist
for i in {1..30}; do
  if docker exec $DASHBOARD_CONTAINER test -f $WAZUH_YML_PATH 2>/dev/null; then
    echo "Dashboard config file found"
    break
  fi
  echo "Waiting for dashboard config file... ($i/30)"
  sleep 5
done

# Update the API password in wazuh.yml
# Escape special characters for sed replacement
ESCAPED_API_PASS_FOR_YML=$(printf '%s\n' "${wazuh_api_pass}" | sed 's/[&/\]/\\&/g')
docker exec $DASHBOARD_CONTAINER bash -c "sed -i 's/password: .*/password: \"$ESCAPED_API_PASS_FOR_YML\"/g' $WAZUH_YML_PATH" 2>/dev/null && \
  echo "Dashboard API password updated" || \
  echo "Warning: Could not update dashboard API password"

# Verify the change
echo "=== Dashboard API configuration ==="
docker exec $DASHBOARD_CONTAINER cat $WAZUH_YML_PATH 2>/dev/null || echo "Could not read dashboard config"

# Restart dashboard to apply changes
echo "Restarting dashboard..."
docker compose restart wazuh.dashboard
sleep 30

# Create agent enrollment script
cat > /opt/wazuh/enroll-agent.sh << 'ENROLL'
#!/bin/bash
# Agent enrollment script
# Usage: ./enroll-agent.sh <agent_name> <agent_ip>

AGENT_NAME=$1
AGENT_IP=$2
WAZUH_MANAGER_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
API_PASS=$(cat /opt/wazuh/.api_pass 2>/dev/null || echo "WazuhAPI123!")

echo "Enrolling agent: $AGENT_NAME ($AGENT_IP)"
echo "Wazuh Manager: $WAZUH_MANAGER_IP"

# Get auth token
TOKEN=$(curl -s -u "wazuh-wui:$API_PASS" -k -X POST "https://localhost:55000/security/user/authenticate?raw=true")

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

API_PASS=$(cat /opt/wazuh/.api_pass 2>/dev/null || echo "WazuhAPI123!")

echo ""
echo "=== Wazuh Manager Info ==="
TOKEN=$(curl -s -u "wazuh-wui:$API_PASS" -k -X POST "https://localhost:55000/security/user/authenticate?raw=true" 2>/dev/null)
if [ -z "$TOKEN" ] || echo "$TOKEN" | grep -q "error"; then
  echo "API authentication failed. Token response: $TOKEN"
  echo "Trying with default password..."
  TOKEN=$(curl -s -u "wazuh-wui:MyS3cr37P450r.*-" -k -X POST "https://localhost:55000/security/user/authenticate?raw=true" 2>/dev/null)
fi

if [ -n "$TOKEN" ] && ! echo "$TOKEN" | grep -q "error"; then
  curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/manager/info?pretty=true" | jq .

  echo ""
  echo "=== Connected Agents ==="
  curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/agents?pretty=true" | jq '.data.affected_items[] | {id, name, ip, status}'
else
  echo "Could not authenticate to Wazuh API"
  echo "Check /opt/wazuh/.api_pass or try default: MyS3cr37P450r.*-"
fi
STATUS

chmod +x /opt/wazuh/status.sh

echo "Wazuh Manager setup completed at $(date)"
echo ""
echo "Dashboard URL: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Username: admin"
echo "Password: ${wazuh_admin_pass}"

# ==========================================
# Configure AWS Service Integrations
# ==========================================
echo "Configuring AWS service integrations at $(date)"

# Wait for Wazuh to fully initialize
sleep 30

# Create AWS wodle configuration for ossec.conf
cat > /tmp/aws-wodle-config.xml << 'AWSCONFIG'
  <!-- AWS CloudTrail Integration -->
%{ if cloudtrail_bucket != "" ~}
  <wodle name="aws-s3">
    <disabled>no</disabled>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <skip_on_error>yes</skip_on_error>
    <bucket type="cloudtrail">
      <name>${cloudtrail_bucket}</name>
      <aws_profile>default</aws_profile>
      <regions>${aws_region}</regions>
    </bucket>
  </wodle>
%{ endif ~}

%{ if config_bucket != "" ~}
  <!-- AWS Config Integration -->
  <wodle name="aws-s3">
    <disabled>no</disabled>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <skip_on_error>yes</skip_on_error>
    <bucket type="config">
      <name>${config_bucket}</name>
      <aws_profile>default</aws_profile>
      <regions>${aws_region}</regions>
    </bucket>
  </wodle>
%{ endif ~}

%{ if vpc_flow_logs_group != "" ~}
  <!-- VPC Flow Logs Integration via CloudWatch -->
  <wodle name="aws-cloudwatchlogs">
    <disabled>no</disabled>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <log_group>${vpc_flow_logs_group}</log_group>
    <aws_profile>default</aws_profile>
    <regions>${aws_region}</regions>
  </wodle>
%{ endif ~}

  <!-- GuardDuty Native Integration -->
  <wodle name="aws-s3">
    <disabled>no</disabled>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <skip_on_error>yes</skip_on_error>
    <service type="guardduty">
      <aws_profile>default</aws_profile>
      <regions>${aws_region}</regions>
    </service>
  </wodle>
AWSCONFIG

# Inject AWS wodle configuration into Wazuh Manager ossec.conf
# We need to do this inside the container
docker exec single-node-wazuh.manager-1 bash -c '
  # Check if aws-s3 wodle already exists
  if ! grep -q "wodle name=\"aws-s3\"" /var/ossec/etc/ossec.conf; then
    # Insert AWS configuration before closing </ossec_config> tag
    sed -i "/<\/ossec_config>/i\\
$(cat /dev/stdin | sed "s/$/\\\\n/" | tr -d "\n")
" /var/ossec/etc/ossec.conf
  fi
' < /tmp/aws-wodle-config.xml 2>/dev/null || echo "AWS wodle configuration skipped - container may need manual config"

# Restart Wazuh manager to apply configuration
docker exec single-node-wazuh.manager-1 /var/ossec/bin/wazuh-control restart 2>/dev/null || echo "Wazuh restart skipped"

rm /tmp/aws-wodle-config.xml

echo "AWS service integrations configured at $(date)"
