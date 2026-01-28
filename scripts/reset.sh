#!/bin/bash
# Wiz Exercise - Reset/Destroy Script
# Tears down all infrastructure

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

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm_destroy() {
    echo -e "${RED}"
    echo "  ██████╗ ███████╗███████╗████████╗██████╗  ██████╗ ██╗   ██╗"
    echo "  ██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗╚██╗ ██╔╝"
    echo "  ██║  ██║█████╗  ███████╗   ██║   ██████╔╝██║   ██║ ╚████╔╝ "
    echo "  ██║  ██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║  ╚██╔╝  "
    echo "  ██████╔╝███████╗███████║   ██║   ██║  ██║╚██████╔╝   ██║   "
    echo "  ╚═════╝ ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   "
    echo -e "${NC}"
    echo ""
    warn "This will PERMANENTLY DELETE all infrastructure:"
    echo "  - EC2 instances (MongoDB, Wazuh, Red Team)"
    echo "  - EKS cluster and node groups"
    echo "  - S3 buckets and their contents"
    echo "  - VPC, subnets, NAT gateway"
    echo "  - IAM roles and policies"
    echo "  - Security groups"
    echo "  - CloudTrail, GuardDuty, Security Hub configs"
    echo ""
    echo -e "${RED}THIS ACTION CANNOT BE UNDONE!${NC}"
    echo ""

    read -p "Type 'DESTROY' to confirm: " confirmation
    if [ "$confirmation" != "DESTROY" ]; then
        info "Destroy cancelled"
        exit 0
    fi
}

destroy_via_github_actions() {
    header "Destroying via GitHub Actions"

    if ! gh auth status &>/dev/null; then
        error "Not authenticated with GitHub CLI"
        exit 1
    fi

    confirm_destroy

    info "Triggering destroy workflow..."
    gh workflow run "Deploy Infrastructure" --field action=destroy

    sleep 5

    # Get run ID
    RUN_ID=$(gh run list --workflow="Deploy Infrastructure" --limit 1 --json databaseId --jq '.[0].databaseId')
    info "Workflow run ID: $RUN_ID"

    # Watch the workflow
    info "Watching workflow progress..."
    gh run watch "$RUN_ID"

    # Check result
    CONCLUSION=$(gh run view "$RUN_ID" --json conclusion --jq '.conclusion')
    if [ "$CONCLUSION" = "success" ]; then
        info "Destroy successful!"
    else
        error "Destroy failed. Check: gh run view $RUN_ID --log"
        exit 1
    fi
}

destroy_locally() {
    header "Destroying Locally with Terraform"

    confirm_destroy

    cd "$PROJECT_DIR/terraform"

    # Set required TF variables (even for destroy)
    export TF_VAR_mongodb_admin_pass="${MONGODB_ADMIN_PASS:-dummy}"
    export TF_VAR_mongodb_app_pass="${MONGODB_APP_PASS:-dummy}"
    export TF_VAR_backup_encryption_key="${BACKUP_ENCRYPTION_KEY:-dummy}"
    export TF_VAR_wazuh_admin_password="${WAZUH_ADMIN_PASS:-dummy}"
    export TF_VAR_wazuh_api_password="${WAZUH_API_PASS:-dummy}"
    export TF_VAR_container_image="nginx:latest"

    info "Initializing Terraform..."
    terraform init

    info "Planning destroy..."
    terraform plan -destroy -var-file="environments/demo.tfvars" -out=tfplan-destroy

    info "Destroying infrastructure..."
    terraform apply tfplan-destroy

    info "Infrastructure destroyed!"
}

destroy_bootstrap() {
    header "Destroying Bootstrap State Backend"

    warn "This will delete the Terraform state backend!"
    warn "Only do this if you've already destroyed all other infrastructure."
    echo ""

    read -p "Type 'DELETE-STATE' to confirm: " confirmation
    if [ "$confirmation" != "DELETE-STATE" ]; then
        info "Cancelled"
        return
    fi

    cd "$PROJECT_DIR/terraform/bootstrap"

    info "Destroying state backend..."
    terraform destroy -auto-approve

    info "State backend destroyed!"
}

cleanup_local_files() {
    header "Cleaning Up Local Files"

    info "Removing local Terraform files..."
    rm -rf "$PROJECT_DIR/terraform/.terraform"
    rm -f "$PROJECT_DIR/terraform/.terraform.lock.hcl"
    rm -f "$PROJECT_DIR/terraform/tfplan"*
    rm -f "$PROJECT_DIR/terraform/terraform.tfstate"*

    rm -rf "$PROJECT_DIR/terraform/bootstrap/.terraform"
    rm -f "$PROJECT_DIR/terraform/bootstrap/.terraform.lock.hcl"
    rm -f "$PROJECT_DIR/terraform/bootstrap/terraform.tfstate"*

    info "Removing SSH keys..."
    rm -f /tmp/mongodb-key.pem
    rm -f /tmp/wazuh-key.pem
    rm -f /tmp/redteam-key.pem

    info "Removing kubeconfig context..."
    kubectl config delete-context "arn:aws:eks:$AWS_REGION:*:cluster/wiz-exercise-eks" 2>/dev/null || true

    info "Local cleanup complete!"
}

show_resources() {
    header "Current Resources"

    info "EC2 Instances:"
    aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=wiz-exercise" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name}' \
        --output table \
        --region "$AWS_REGION" 2>/dev/null || echo "  None found"

    echo ""
    info "S3 Buckets:"
    aws s3 ls --region "$AWS_REGION" 2>/dev/null | grep wiz || echo "  None found"

    echo ""
    info "EKS Clusters:"
    aws eks list-clusters --region "$AWS_REGION" --query 'clusters[?contains(@,`wiz`)]' --output text 2>/dev/null || echo "  None found"

    echo ""
    info "VPCs:"
    aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=wiz-exercise" \
        --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock}' \
        --output table \
        --region "$AWS_REGION" 2>/dev/null || echo "  None found"
}

emergency_cleanup() {
    header "Emergency Cleanup"

    warn "This will forcefully delete resources that may be stuck."
    warn "Use only if normal destroy fails."
    echo ""

    read -p "Type 'FORCE' to confirm: " confirmation
    if [ "$confirmation" != "FORCE" ]; then
        info "Cancelled"
        return
    fi

    # Terminate EC2 instances
    info "Terminating EC2 instances..."
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=wiz-exercise" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)

    if [ -n "$INSTANCE_IDS" ]; then
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
        info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region "$AWS_REGION" 2>/dev/null || true
    fi

    # Delete EKS node groups
    info "Deleting EKS node groups..."
    aws eks delete-nodegroup \
        --cluster-name wiz-exercise-eks \
        --nodegroup-name wiz-exercise-eks-nodes \
        --region "$AWS_REGION" 2>/dev/null || true

    info "Waiting for node group deletion (this may take a while)..."
    aws eks wait nodegroup-deleted \
        --cluster-name wiz-exercise-eks \
        --nodegroup-name wiz-exercise-eks-nodes \
        --region "$AWS_REGION" 2>/dev/null || true

    # Delete EKS cluster
    info "Deleting EKS cluster..."
    aws eks delete-cluster --name wiz-exercise-eks --region "$AWS_REGION" 2>/dev/null || true

    info "Waiting for cluster deletion..."
    aws eks wait cluster-deleted --name wiz-exercise-eks --region "$AWS_REGION" 2>/dev/null || true

    # Empty and delete S3 buckets
    info "Deleting S3 buckets..."
    for BUCKET in $(aws s3 ls --region "$AWS_REGION" 2>/dev/null | awk '{print $3}' | grep wiz-exercise); do
        info "Emptying $BUCKET..."
        aws s3 rm "s3://$BUCKET" --recursive --region "$AWS_REGION" 2>/dev/null || true
        info "Deleting $BUCKET..."
        aws s3 rb "s3://$BUCKET" --force --region "$AWS_REGION" 2>/dev/null || true
    done

    # Delete NAT Gateway
    info "Deleting NAT Gateways..."
    NAT_IDS=$(aws ec2 describe-nat-gateways \
        --filter "Name=tag:Project,Values=wiz-exercise" \
        --query 'NatGateways[*].NatGatewayId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)

    for NAT_ID in $NAT_IDS; do
        aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" --region "$AWS_REGION" 2>/dev/null || true
    done

    info "Emergency cleanup initiated. Some resources may take time to delete."
    info "Run 'show resources' to check remaining resources."
}

show_menu() {
    header "WIZ EXERCISE - RESET/DESTROY"
    echo "Select action:"
    echo ""
    echo "  1) Destroy via GitHub Actions (recommended)"
    echo "  2) Destroy locally with Terraform"
    echo "  3) Show current resources"
    echo "  4) Cleanup local files only"
    echo "  5) Emergency force cleanup"
    echo "  6) Destroy bootstrap state backend"
    echo "  0) Exit"
    echo ""
    read -p "Enter choice [0-6]: " choice
}

# Parse command line args
case "${1:-}" in
    --github|--gh)
        destroy_via_github_actions
        exit 0
        ;;
    --local)
        destroy_locally
        exit 0
        ;;
    --force)
        emergency_cleanup
        exit 0
        ;;
    --cleanup)
        cleanup_local_files
        exit 0
        ;;
    --show)
        show_resources
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --github, --gh    Destroy via GitHub Actions"
        echo "  --local           Destroy locally with Terraform"
        echo "  --force           Emergency force cleanup"
        echo "  --cleanup         Cleanup local files only"
        echo "  --show            Show current resources"
        echo "  --help, -h        Show this help"
        echo ""
        echo "Run without options for interactive menu."
        exit 0
        ;;
esac

# Interactive menu
while true; do
    show_menu

    case $choice in
        1) destroy_via_github_actions ;;
        2) destroy_locally ;;
        3) show_resources ;;
        4) cleanup_local_files ;;
        5) emergency_cleanup ;;
        6) destroy_bootstrap ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option" ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
