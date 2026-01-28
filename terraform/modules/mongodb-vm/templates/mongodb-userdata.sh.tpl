#!/bin/bash
set -e

# Log everything to file
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting MongoDB setup at $(date)"

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

# Install dependencies
apt-get install -y gnupg curl awscli jq

# Add MongoDB 4.4 repository (INTENTIONALLY OUTDATED VERSION)
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-4.4.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# Install MongoDB 4.4
apt-get update
apt-get install -y mongodb-org=4.4.29 mongodb-org-server=4.4.29 mongodb-org-shell=4.4.29 mongodb-org-mongos=4.4.29 mongodb-org-tools=4.4.29

# Pin MongoDB version to prevent auto-updates
echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-org-shell hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections

# Configure MongoDB to listen on all interfaces
cat > /etc/mongod.conf << 'EOF'
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
EOF

# Start MongoDB
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to be ready
sleep 10
until mongosh --eval "print('MongoDB is ready')" 2>/dev/null; do
  echo "Waiting for MongoDB to start..."
  sleep 2
done

# Create admin user
mongosh admin --eval "
db.createUser({
  user: '${mongodb_admin_user}',
  pwd: '${mongodb_admin_pass}',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
})
"

# Create application database and user
mongosh admin -u "${mongodb_admin_user}" -p "${mongodb_admin_pass}" --eval "
use ${mongodb_database}
db.createUser({
  user: '${mongodb_app_user}',
  pwd: '${mongodb_app_pass}',
  roles: [
    { role: 'readWrite', db: '${mongodb_database}' }
  ]
})
"

# Create backup script
cat > /usr/local/bin/mongodb-backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb-backup-$TIMESTAMP"
BACKUP_FILE="mongodb-backup-$TIMESTAMP.tar.gz"
BUCKET="${backup_bucket}"
ENCRYPTION_KEY="${backup_encryption_key}"

echo "Starting MongoDB backup at $(date)"

# Create backup
mkdir -p "$BACKUP_DIR"
mongodump --uri="mongodb://${mongodb_admin_user}:${mongodb_admin_pass}@localhost:27017/?authSource=admin" --out="$BACKUP_DIR"

# Compress backup
cd /tmp
tar -czf "$BACKUP_FILE" "mongodb-backup-$TIMESTAMP"

# Encrypt if key provided
if [ -n "$ENCRYPTION_KEY" ]; then
  gpg --batch --yes --passphrase "$ENCRYPTION_KEY" --symmetric --cipher-algo AES256 "$BACKUP_FILE"
  BACKUP_FILE="$BACKUP_FILE.gpg"
fi

# Upload to S3
aws s3 cp "/tmp/$BACKUP_FILE" "s3://$BUCKET/backups/$BACKUP_FILE"

# Cleanup
rm -rf "$BACKUP_DIR" "/tmp/mongodb-backup-$TIMESTAMP.tar.gz" "/tmp/mongodb-backup-$TIMESTAMP.tar.gz.gpg" 2>/dev/null || true

echo "Backup completed successfully at $(date)"
BACKUP_SCRIPT

chmod +x /usr/local/bin/mongodb-backup.sh

# Set up daily cron job for backups
echo "0 2 * * * root /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1" > /etc/cron.d/mongodb-backup
chmod 0644 /etc/cron.d/mongodb-backup

# Run initial backup
/usr/local/bin/mongodb-backup.sh || echo "Initial backup failed, will retry on schedule"

# Install CloudWatch agent for monitoring (optional but useful for demo)
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb || apt-get install -f -y
rm amazon-cloudwatch-agent.deb

echo "MongoDB setup completed at $(date)"
echo "MongoDB version: $(mongod --version | head -1)"
