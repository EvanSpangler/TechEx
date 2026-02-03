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

# Clone Wazuh Docker repository (latest stable)
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.2

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
# Use a more flexible pattern that matches the entire value after API_PASSWORD=
sed -i "s/API_PASSWORD=.*/API_PASSWORD=$ESCAPED_API_PASS/g" docker-compose.yml

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
# Note: sed -i fails inside Docker volume mounts ("Device or resource busy"),
# and the Dashboard may regenerate wazuh.yml after initial startup.
# We must wait for the Dashboard to fully initialize, then write the complete
# file using cp (not sed -i) and restart.
echo "=== Updating Dashboard API configuration ==="
DASHBOARD_CONTAINER="single-node-wazuh.dashboard-1"
WAZUH_YML_PATH="/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"

# Wait for the dashboard to be fully ready (health check on port 5601)
echo "Waiting for Dashboard to fully initialize..."
for i in {1..60}; do
  if docker exec $DASHBOARD_CONTAINER curl -sk -o /dev/null -w '%%{http_code}' https://localhost:5601/api/status 2>/dev/null | grep -q "200\|401"; then
    echo "Dashboard is ready"
    break
  fi
  echo "Waiting for Dashboard health... ($i/60)"
  sleep 10
done

# Write the complete wazuh.yml with correct credentials
# Using cp instead of sed -i to avoid "Device or resource busy" on Docker volumes
docker exec -u root $DASHBOARD_CONTAINER bash -c "cat > /tmp/wazuh.yml << 'WAZUHCFG'
hosts:
  - default:
      url: \"https://wazuh.manager\"
      port: 55000
      username: wazuh-wui
      password: \"${wazuh_api_pass}\"
      run_as: false
WAZUHCFG
cp /tmp/wazuh.yml $WAZUH_YML_PATH && rm /tmp/wazuh.yml" 2>/dev/null && \
  echo "Dashboard API configuration written" || \
  echo "Warning: Could not write dashboard API configuration"

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
# Note: Wazuh 4.x uses aws-s3 wodle for all AWS integrations
# CloudWatch Logs is a service type, not a separate wodle
# Instance metadata is used for credentials (no aws_profile needed)
cat > /tmp/aws-wodle-config.xml << 'AWSCONFIG'
  <!-- AWS Integrations - Single wodle with multiple sources -->
  <wodle name="aws-s3">
    <disabled>no</disabled>
    <interval>5m</interval>
    <run_on_start>yes</run_on_start>
    <skip_on_error>yes</skip_on_error>

%{ if cloudtrail_bucket != "" ~}
    <!-- CloudTrail Logs from S3 -->
    <bucket type="cloudtrail">
      <name>${cloudtrail_bucket}</name>
      <regions>${aws_region}</regions>
    </bucket>
%{ endif ~}

%{ if config_bucket != "" ~}
    <!-- AWS Config Logs from S3 -->
    <bucket type="config">
      <name>${config_bucket}</name>
      <regions>${aws_region}</regions>
    </bucket>
%{ endif ~}

%{ if vpc_flow_logs_group != "" ~}
    <!-- VPC Flow Logs via CloudWatch -->
    <service type="cloudwatchlogs">
      <aws_log_groups>${vpc_flow_logs_group}</aws_log_groups>
      <regions>${aws_region}</regions>
    </service>
%{ endif ~}

%{ if eks_log_group != "" ~}
    <!-- EKS Audit Logs via CloudWatch -->
    <service type="cloudwatchlogs">
      <aws_log_groups>${eks_log_group}</aws_log_groups>
      <regions>${aws_region}</regions>
    </service>
%{ endif ~}

    <!-- AWS Inspector findings -->
    <service type="inspector">
      <regions>${aws_region}</regions>
    </service>
  </wodle>
AWSCONFIG

# Inject AWS wodle configuration into Wazuh Manager ossec.conf
# We need to do this inside the container
MANAGER_CONTAINER="single-node-wazuh.manager-1"

# Wait for the manager container to be fully ready
for i in {1..60}; do
  if docker exec $MANAGER_CONTAINER test -f /var/ossec/etc/ossec.conf 2>/dev/null; then
    echo "Manager ossec.conf found"
    break
  fi
  echo "Waiting for manager to be ready... ($i/60)"
  sleep 5
done

# Copy the config file into the container first
docker cp /tmp/aws-wodle-config.xml $MANAGER_CONTAINER:/tmp/aws-wodle.xml 2>/dev/null || echo "Could not copy config to container"

# Check if aws-s3 wodle already exists, if not, inject it
docker exec $MANAGER_CONTAINER bash -c '
  if ! grep -q "wodle name=\"aws-s3\"" /var/ossec/etc/ossec.conf; then
    # Create backup
    cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
    # Insert the AWS config before the closing </ossec_config> tag
    head -n -1 /var/ossec/etc/ossec.conf > /tmp/ossec_new.conf
    cat /tmp/aws-wodle.xml >> /tmp/ossec_new.conf
    echo "</ossec_config>" >> /tmp/ossec_new.conf
    mv /tmp/ossec_new.conf /var/ossec/etc/ossec.conf
    rm -f /tmp/aws-wodle.xml
    echo "AWS wodle configuration injected"
  else
    echo "AWS wodle already configured"
  fi
' 2>/dev/null || echo "AWS wodle configuration skipped - container may need manual config"

# Note: Do NOT restart the manager here - let it finish initialization naturally
# The configuration will be picked up on the next restart or can be applied manually
echo "AWS wodle configuration complete - restart manager manually if needed: docker exec $MANAGER_CONTAINER /var/ossec/bin/wazuh-control restart"

rm /tmp/aws-wodle-config.xml

echo "AWS service integrations configured at $(date)"

# ==========================================
# Configure Custom Detection Rules for Attack Chain Demo
# ==========================================
echo "Configuring custom attack chain detection rules at $(date)"

# Create custom rules XML for detecting WIZ exercise attack patterns
cat > /tmp/attack-chain-rules.xml << 'ATTACKRULES'
<!-- WIZ Exercise - Attack Chain Detection Rules -->
<!-- Custom rules for detecting demo attack patterns with HIGH/CRITICAL severity -->

<group name="attack_chain,">

  <!-- Phase 1: SSM Parameter Enumeration (Recon) -->
  <rule id="100001" level="10">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">DescribeParameters</field>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>HIGH: AWS SSM Parameter Enumeration Detected (WIZ Attack Chain Phase 1 - Recon)</description>
    <group>aws,recon,attack_chain,pci_dss_10.6.1,</group>
  </rule>

  <!-- Phase 1: EC2 Instance Enumeration (Recon) -->
  <rule id="100002" level="8">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">DescribeInstances</field>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>MEDIUM: AWS EC2 Instance Enumeration (WIZ Attack Chain Phase 1 - Recon)</description>
    <group>aws,recon,attack_chain,</group>
  </rule>

  <!-- Phase 2: Unauthenticated S3 Bucket Listing -->
  <rule id="100003" level="12">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">ListBucket</field>
    <field name="aws.userIdentity.type">AWSAccount</field>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>HIGH: Unauthenticated S3 Bucket Listing (WIZ Attack Chain Phase 2 - Exfil)</description>
    <group>aws,exfiltration,attack_chain,pci_dss_10.6.1,</group>
  </rule>

  <!-- Phase 2: Unauthenticated S3 Object Download -->
  <rule id="100004" level="14">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">GetObject</field>
    <field name="aws.userIdentity.type">AWSAccount</field>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>CRITICAL: Unauthenticated S3 Object Download (WIZ Attack Chain Phase 2 - Data Exfiltration)</description>
    <group>aws,exfiltration,attack_chain,pci_dss_10.6.1,gdpr_IV_35.7.d,</group>
  </rule>

  <!-- Phase 3: SSH Private Key Retrieval from SSM -->
  <rule id="100005" level="15">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">GetParameter</field>
    <regex>ssh-private-key</regex>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>CRITICAL: SSH Private Key Retrieved from SSM Parameter Store (WIZ Attack Chain Phase 3 - Credential Theft)</description>
    <group>aws,credential_theft,attack_chain,pci_dss_8.2.1,</group>
  </rule>

  <!-- Phase 4: Overprivileged IAM - MongoDB role doing EC2 enumeration -->
  <rule id="100006" level="12">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">DescribeInstances</field>
    <regex>mongodb-role</regex>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>HIGH: EC2 Enumeration from MongoDB Instance Role (WIZ Attack Chain Phase 4 - Privilege Abuse)</description>
    <group>aws,privilege_escalation,attack_chain,pci_dss_10.2.5,</group>
  </rule>

  <!-- Phase 4: IMDS Credential Theft - curl to metadata service -->
  <rule id="100010" level="15">
    <if_group>syslog</if_group>
    <match>169.254.169.254</match>
    <match>security-credentials</match>
    <description>CRITICAL: IMDS Credential Theft Attempt Detected (WIZ Attack Chain Phase 4 - Privilege Escalation)</description>
    <group>imds,credential_theft,attack_chain,pci_dss_8.2.1,</group>
  </rule>

  <!-- Phase 3: SSH Lateral Movement - Accepted SSH to MongoDB -->
  <rule id="100011" level="10">
    <if_sid>5715</if_sid>
    <match>mongodb</match>
    <description>HIGH: SSH Lateral Movement to MongoDB Instance (WIZ Attack Chain Phase 3)</description>
    <group>ssh,lateral_movement,attack_chain,pci_dss_10.2.4,</group>
  </rule>

  <!-- Phase 3: SSH Lateral Movement - SSH from Red Team instance -->
  <rule id="100012" level="10">
    <if_sid>5715</if_sid>
    <match>redteam</match>
    <description>HIGH: SSH Connection from Red Team Instance (WIZ Attack Chain Phase 3)</description>
    <group>ssh,lateral_movement,attack_chain,</group>
  </rule>

  <!-- Generic: Suspicious AWS API call patterns -->
  <rule id="100020" level="8">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">GetSecretValue</field>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>MEDIUM: AWS Secrets Manager Access Detected</description>
    <group>aws,credential_access,attack_chain,</group>
  </rule>

  <!-- Generic: AWS GuardDuty findings (if integrated) -->
  <rule id="100021" level="12">
    <if_sid>80200</if_sid>
    <field name="aws.eventSource">guardduty.amazonaws.com</field>
    <field name="aws.sourceIPAddress" negate="yes">204.111.196.200</field>
    <description>HIGH: AWS GuardDuty Finding Detected</description>
    <group>aws,guardduty,attack_chain,</group>
  </rule>

</group>
ATTACKRULES

# Inject custom rules into Wazuh Manager
echo "Injecting custom attack chain rules into Wazuh Manager..."

docker cp /tmp/attack-chain-rules.xml $MANAGER_CONTAINER:/tmp/attack-chain-rules.xml 2>/dev/null || echo "Could not copy rules to container"

# Create or update local_rules.xml with our custom rules
docker exec $MANAGER_CONTAINER bash -c '
  LOCAL_RULES="/var/ossec/etc/rules/local_rules.xml"
  
  # Check if local_rules.xml exists and has our rules
  if [ -f "$LOCAL_RULES" ] && grep -q "attack_chain" "$LOCAL_RULES"; then
    echo "Attack chain rules already present in local_rules.xml"
  else
    # Backup existing local_rules.xml if it exists
    [ -f "$LOCAL_RULES" ] && cp "$LOCAL_RULES" "$${LOCAL_RULES}.bak"
    
    # Create new local_rules.xml with our custom rules
    echo "<!-- Wazuh custom rules -->" > "$LOCAL_RULES"
    cat /tmp/attack-chain-rules.xml >> "$LOCAL_RULES"
    
    # Validate the rules
    if /var/ossec/bin/wazuh-logtest -U 100001:100021 2>/dev/null; then
      echo "Custom rules validated successfully"
    else
      echo "Note: Rule validation returned non-zero (rules might still work)"
    fi
    
    echo "Custom attack chain rules injected into $LOCAL_RULES"
  fi
  rm -f /tmp/attack-chain-rules.xml
' 2>/dev/null || echo "Custom rules injection skipped - container may need manual config"

rm /tmp/attack-chain-rules.xml

# Restart Wazuh Manager to load new rules
echo "Restarting Wazuh Manager to load custom rules..."
docker exec $MANAGER_CONTAINER /var/ossec/bin/wazuh-control restart 2>/dev/null || echo "Manager restart skipped - may need manual restart"

echo "Custom attack chain detection rules configured at $(date)"
