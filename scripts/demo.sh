#!/bin/bash
# Wiz Exercise - Demo Script
# Demonstrates the intentional security vulnerabilities

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

vuln() {
    echo -e "${RED}[VULNERABILITY]${NC} $1"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[DEMO]${NC} $1"
}

# Get Terraform outputs
get_output() {
    cd "$PROJECT_DIR/terraform"
    terraform output -raw "$1" 2>/dev/null
}

show_menu() {
    header "WIZ EXERCISE - VULNERABILITY DEMOS"
    echo "Select a demo to run:"
    echo ""
    echo "  1) Public S3 Bucket Access"
    echo "  2) SSH to MongoDB (exposed to internet)"
    echo "  3) Overprivileged IAM Role on MongoDB"
    echo "  4) K8s Cluster-Admin ServiceAccount"
    echo "  5) K8s Secrets Exposure"
    echo "  6) SSH to Red Team Instance"
    echo "  7) Access Wazuh Dashboard"
    echo "  8) Full Attack Chain Demo"
    echo "  9) Show All Infrastructure"
    echo "  0) Exit"
    echo ""
    read -p "Enter choice [0-9]: " choice
}

demo_public_s3() {
    header "DEMO 1: Public S3 Bucket Access"

    BUCKET=$(get_output backup_bucket_name)

    vuln "S3 bucket is publicly accessible without authentication"
    echo ""
    warn "Listing bucket contents anonymously..."
    echo -e "${YELLOW}Command: aws s3 ls s3://$BUCKET --no-sign-request${NC}"
    echo ""

    aws s3 ls "s3://$BUCKET" --no-sign-request 2>&1 || true

    echo ""
    warn "Reading README.txt from public bucket..."
    echo -e "${YELLOW}Command: aws s3 cp s3://$BUCKET/README.txt - --no-sign-request${NC}"
    echo ""

    aws s3 cp "s3://$BUCKET/README.txt" - --no-sign-request 2>&1 || true
}

demo_mongodb_ssh() {
    header "DEMO 2: MongoDB SSH Access (Exposed to Internet)"

    MONGODB_IP=$(get_output mongodb_public_ip)
    SSM_KEY=$(get_output mongodb_ssh_key_ssm)

    vuln "MongoDB instance has SSH (port 22) exposed to 0.0.0.0/0"
    vuln "Running outdated Ubuntu 20.04 with MongoDB 4.4"
    echo ""

    info "MongoDB Public IP: $MONGODB_IP"
    info "SSH Key stored in SSM: $SSM_KEY"
    echo ""

    warn "To SSH into MongoDB:"
    echo -e "${YELLOW}aws ssm get-parameter --name $SSM_KEY --with-decryption --query 'Parameter.Value' --output text > /tmp/mongodb-key.pem${NC}"
    echo -e "${YELLOW}chmod 600 /tmp/mongodb-key.pem${NC}"
    echo -e "${YELLOW}ssh -i /tmp/mongodb-key.pem ubuntu@$MONGODB_IP${NC}"
    echo ""

    read -p "Connect now? [y/N]: " connect
    if [[ "$connect" =~ ^[Yy]$ ]]; then
        aws ssm get-parameter --name "$SSM_KEY" --with-decryption --query 'Parameter.Value' --output text --region "$AWS_REGION" > /tmp/mongodb-key.pem
        chmod 600 /tmp/mongodb-key.pem
        ssh -o StrictHostKeyChecking=no -i /tmp/mongodb-key.pem ubuntu@"$MONGODB_IP"
    fi
}

demo_overprivileged_iam() {
    header "DEMO 3: Overprivileged IAM Role on MongoDB"

    vuln "MongoDB EC2 instance has overprivileged IAM role with:"
    vuln "  - s3:* on all resources"
    vuln "  - ec2:Describe* on all resources"
    vuln "  - iam:Get*, iam:List* on all resources"
    vuln "  - secretsmanager:GetSecretValue on all resources"
    echo ""

    warn "From the MongoDB instance, an attacker could:"
    echo "  - List and access ALL S3 buckets"
    echo "  - Enumerate EC2 instances"
    echo "  - List IAM users/roles/policies"
    echo "  - Read secrets from Secrets Manager"
    echo ""

    info "IAM Role: wiz-exercise-mongodb-role"
    echo ""

    warn "Example commands from MongoDB instance:"
    echo -e "${YELLOW}aws s3 ls${NC}"
    echo -e "${YELLOW}aws ec2 describe-instances${NC}"
    echo -e "${YELLOW}aws iam list-users${NC}"
    echo -e "${YELLOW}aws secretsmanager list-secrets${NC}"
}

demo_k8s_cluster_admin() {
    header "DEMO 4: K8s Cluster-Admin ServiceAccount"

    vuln "Application ServiceAccount has cluster-admin privileges"
    echo ""

    # Configure kubectl
    EKS_NAME=$(get_output eks_cluster_name)
    aws eks update-kubeconfig --name "$EKS_NAME" --region "$AWS_REGION" 2>/dev/null

    info "Checking ServiceAccount binding..."
    echo ""

    kubectl get clusterrolebinding tasky-cluster-admin -o yaml 2>/dev/null | head -20

    echo ""
    warn "This means any pod in the tasky namespace can:"
    echo "  - Create/delete any resource in the cluster"
    echo "  - Access secrets in all namespaces"
    echo "  - Modify RBAC permissions"
    echo "  - Deploy malicious workloads"
}

demo_k8s_secrets() {
    header "DEMO 5: K8s Secrets Exposure"

    vuln "MongoDB credentials stored as K8s Secret (base64 encoded, not encrypted)"
    echo ""

    # Configure kubectl
    EKS_NAME=$(get_output eks_cluster_name)
    aws eks update-kubeconfig --name "$EKS_NAME" --region "$AWS_REGION" 2>/dev/null

    warn "Listing secrets in tasky namespace..."
    kubectl get secrets -n tasky

    echo ""
    warn "Decoding MongoDB URI from secret..."
    echo -e "${YELLOW}Command: kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.MONGODB_URI}' | base64 -d${NC}"
    echo ""

    MONGO_URI=$(kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.MONGODB_URI}' 2>/dev/null | base64 -d)
    echo -e "${RED}MongoDB URI: $MONGO_URI${NC}"

    echo ""
    warn "Decoding JWT secret..."
    JWT=$(kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.SECRET_KEY}' 2>/dev/null | base64 -d)
    echo -e "${RED}JWT Secret: $JWT${NC}"
}

demo_redteam_ssh() {
    header "DEMO 6: Red Team Instance Access"

    REDTEAM_IP=$(get_output redteam_public_ip)
    SSM_KEY=$(get_output redteam_ssh_key_ssm)

    info "Red Team Instance: $REDTEAM_IP"
    info "Pre-installed tools: nmap, nikto, sqlmap, hydra, metasploit, etc."
    echo ""

    warn "To SSH into Red Team instance:"
    echo -e "${YELLOW}aws ssm get-parameter --name $SSM_KEY --with-decryption --query 'Parameter.Value' --output text > /tmp/redteam-key.pem${NC}"
    echo -e "${YELLOW}chmod 600 /tmp/redteam-key.pem${NC}"
    echo -e "${YELLOW}ssh -i /tmp/redteam-key.pem ubuntu@$REDTEAM_IP${NC}"
    echo ""

    read -p "Connect now? [y/N]: " connect
    if [[ "$connect" =~ ^[Yy]$ ]]; then
        aws ssm get-parameter --name "$SSM_KEY" --with-decryption --query 'Parameter.Value' --output text --region "$AWS_REGION" > /tmp/redteam-key.pem
        chmod 600 /tmp/redteam-key.pem
        ssh -o StrictHostKeyChecking=no -i /tmp/redteam-key.pem ubuntu@"$REDTEAM_IP"
    fi
}

demo_wazuh() {
    header "DEMO 7: Wazuh SIEM Dashboard"

    WAZUH_IP=$(get_output wazuh_public_ip)

    info "Wazuh Dashboard URL: https://$WAZUH_IP"
    info "Username: admin"
    info "Password: (check SSM parameter or GitHub secret)"
    echo ""

    warn "Wazuh monitors:"
    echo "  - File integrity"
    echo "  - Security events"
    echo "  - Vulnerability detection"
    echo "  - Compliance (PCI-DSS, HIPAA, etc.)"
    echo ""

    read -p "Open in browser? [y/N]: " open
    if [[ "$open" =~ ^[Yy]$ ]]; then
        xdg-open "https://$WAZUH_IP" 2>/dev/null || open "https://$WAZUH_IP" 2>/dev/null || echo "Please open https://$WAZUH_IP in your browser"
    fi
}

demo_attack_chain() {
    header "DEMO 8: Full Attack Chain"

    echo "Attack scenario: External attacker to full cluster compromise"
    echo ""

    echo -e "${RED}Step 1: Discover public S3 bucket${NC}"
    echo "  - Attacker finds publicly accessible backup bucket"
    echo "  - Downloads sensitive data or finds credentials"
    echo ""

    echo -e "${RED}Step 2: SSH to MongoDB (exposed port 22)${NC}"
    echo "  - Attacker scans for open SSH ports"
    echo "  - Exploits weak credentials or vulnerabilities"
    echo ""

    echo -e "${RED}Step 3: Leverage overprivileged IAM role${NC}"
    echo "  - From MongoDB, use instance role to access AWS APIs"
    echo "  - Enumerate all S3 buckets, EC2 instances, IAM"
    echo "  - Read secrets from Secrets Manager"
    echo ""

    echo -e "${RED}Step 4: Access EKS cluster${NC}"
    echo "  - Use discovered credentials to access K8s"
    echo "  - ServiceAccount has cluster-admin privileges"
    echo ""

    echo -e "${RED}Step 5: Full cluster takeover${NC}"
    echo "  - Access all secrets across namespaces"
    echo "  - Deploy cryptominers or backdoors"
    echo "  - Pivot to other AWS resources"
    echo ""

    vuln "This demonstrates why defense-in-depth is critical!"
}

show_infrastructure() {
    header "DEMO 9: All Infrastructure"

    echo -e "${GREEN}EC2 Instances:${NC}"
    aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=wiz-exercise" \
        --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
        --output table \
        --region "$AWS_REGION"

    echo ""
    echo -e "${GREEN}S3 Buckets:${NC}"
    aws s3 ls --region "$AWS_REGION" | grep wiz

    echo ""
    echo -e "${GREEN}EKS Cluster:${NC}"
    EKS_NAME=$(get_output eks_cluster_name)
    aws eks describe-cluster --name "$EKS_NAME" --region "$AWS_REGION" --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' --output table

    echo ""
    echo -e "${GREEN}K8s Pods:${NC}"
    aws eks update-kubeconfig --name "$EKS_NAME" --region "$AWS_REGION" 2>/dev/null
    kubectl get pods -A
}

# Main loop
while true; do
    show_menu

    case $choice in
        1) demo_public_s3 ;;
        2) demo_mongodb_ssh ;;
        3) demo_overprivileged_iam ;;
        4) demo_k8s_cluster_admin ;;
        5) demo_k8s_secrets ;;
        6) demo_redteam_ssh ;;
        7) demo_wazuh ;;
        8) demo_attack_chain ;;
        9) show_infrastructure ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option" ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
