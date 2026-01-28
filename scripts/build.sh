#!/bin/bash
# Wiz Exercise - Build/Deploy Script
# Deploys all infrastructure via GitHub Actions or locally

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

check_prerequisites() {
    header "Checking Prerequisites"

    local missing=0

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        info "AWS CLI: $(aws --version | head -1)"
    else
        error "AWS CLI not installed"
        missing=1
    fi

    # Check Terraform
    if command -v terraform &> /dev/null; then
        info "Terraform: $(terraform version | head -1)"
    else
        error "Terraform not installed"
        missing=1
    fi

    # Check kubectl
    if command -v kubectl &> /dev/null; then
        info "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    else
        warn "kubectl not installed (optional for local deployment)"
    fi

    # Check GitHub CLI
    if command -v gh &> /dev/null; then
        info "GitHub CLI: $(gh --version | head -1)"
    else
        warn "GitHub CLI not installed (required for GitHub Actions deployment)"
    fi

    # Check AWS credentials
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        info "AWS credentials: configured"
        ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")
        info "AWS Account: $ACCOUNT_ID"
    else
        error "AWS credentials not configured"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        error "Missing prerequisites. Please install required tools."
        exit 1
    fi

    info "All prerequisites met!"
}

setup_github_secrets() {
    header "Setting Up GitHub Secrets"

    if ! gh auth status &>/dev/null; then
        warn "Not authenticated with GitHub CLI"
        info "Running: gh auth login"
        gh auth login
    fi

    info "Setting GitHub secrets..."

    # AWS credentials
    gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
    gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"

    # Generate passwords if not set
    MONGODB_ADMIN_PASS="${MONGODB_ADMIN_PASS:-$(openssl rand -base64 16)}"
    MONGODB_APP_PASS="${MONGODB_APP_PASS:-$(openssl rand -base64 16)}"
    BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-$(openssl rand -base64 32)}"
    WAZUH_ADMIN_PASS="${WAZUH_ADMIN_PASS:-$(openssl rand -base64 16)}"
    WAZUH_API_PASS="${WAZUH_API_PASS:-$(openssl rand -base64 16)}"

    gh secret set MONGODB_ADMIN_PASS --body "$MONGODB_ADMIN_PASS"
    gh secret set MONGODB_APP_PASS --body "$MONGODB_APP_PASS"
    gh secret set BACKUP_ENCRYPTION_KEY --body "$BACKUP_ENCRYPTION_KEY"
    gh secret set WAZUH_ADMIN_PASS --body "$WAZUH_ADMIN_PASS"
    gh secret set WAZUH_API_PASS --body "$WAZUH_API_PASS"

    info "GitHub secrets configured!"

    # Save passwords locally for reference
    cat > "$PROJECT_DIR/.secrets" << EOF
# Generated secrets - DO NOT COMMIT
MONGODB_ADMIN_PASS=$MONGODB_ADMIN_PASS
MONGODB_APP_PASS=$MONGODB_APP_PASS
BACKUP_ENCRYPTION_KEY=$BACKUP_ENCRYPTION_KEY
WAZUH_ADMIN_PASS=$WAZUH_ADMIN_PASS
WAZUH_API_PASS=$WAZUH_API_PASS
EOF
    chmod 600 "$PROJECT_DIR/.secrets"
    info "Secrets saved to $PROJECT_DIR/.secrets"
}

bootstrap_terraform_state() {
    header "Bootstrapping Terraform State Backend"

    cd "$PROJECT_DIR/terraform/bootstrap"

    if terraform output bucket_name &>/dev/null; then
        info "State backend already exists"
        return 0
    fi

    info "Initializing bootstrap..."
    terraform init

    info "Creating S3 bucket and DynamoDB table..."
    terraform apply -auto-approve

    info "State backend created!"
}

deploy_via_github_actions() {
    header "Deploying via GitHub Actions"

    if ! gh auth status &>/dev/null; then
        error "Not authenticated with GitHub CLI"
        exit 1
    fi

    # Check if secrets are set
    info "Checking GitHub secrets..."
    SECRETS=$(gh secret list 2>/dev/null | wc -l)
    if [ "$SECRETS" -lt 5 ]; then
        warn "GitHub secrets not fully configured"
        read -p "Set up secrets now? [Y/n]: " setup
        if [[ ! "$setup" =~ ^[Nn]$ ]]; then
            setup_github_secrets
        fi
    fi

    # Trigger workflow
    info "Triggering Deploy Infrastructure workflow..."
    gh workflow run "Deploy Infrastructure" --field action=apply

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
        info "Deployment successful!"
        show_outputs
    else
        error "Deployment failed. Check: gh run view $RUN_ID --log"
        exit 1
    fi
}

deploy_locally() {
    header "Deploying Locally with Terraform"

    cd "$PROJECT_DIR/terraform"

    # Set TF variables
    export TF_VAR_mongodb_admin_pass="${MONGODB_ADMIN_PASS:-$(openssl rand -base64 16)}"
    export TF_VAR_mongodb_app_pass="${MONGODB_APP_PASS:-$(openssl rand -base64 16)}"
    export TF_VAR_backup_encryption_key="${BACKUP_ENCRYPTION_KEY:-$(openssl rand -base64 32)}"
    export TF_VAR_wazuh_admin_password="${WAZUH_ADMIN_PASS:-$(openssl rand -base64 16)}"
    export TF_VAR_wazuh_api_password="${WAZUH_API_PASS:-$(openssl rand -base64 16)}"
    export TF_VAR_container_image="nginx:latest"

    info "Initializing Terraform..."
    terraform init

    info "Validating configuration..."
    terraform validate

    info "Planning deployment..."
    terraform plan -var-file="environments/demo.tfvars" -out=tfplan

    read -p "Apply this plan? [y/N]: " apply
    if [[ "$apply" =~ ^[Yy]$ ]]; then
        info "Applying..."
        terraform apply tfplan
        info "Deployment complete!"
        show_outputs
    else
        info "Deployment cancelled"
    fi
}

show_outputs() {
    header "Deployment Outputs"

    cd "$PROJECT_DIR/terraform"
    terraform output
}

show_menu() {
    header "WIZ EXERCISE - BUILD/DEPLOY"
    echo "Select deployment method:"
    echo ""
    echo "  1) Deploy via GitHub Actions (recommended)"
    echo "  2) Deploy locally with Terraform"
    echo "  3) Bootstrap state backend only"
    echo "  4) Setup GitHub secrets only"
    echo "  5) Check prerequisites"
    echo "  6) Show current outputs"
    echo "  0) Exit"
    echo ""
    read -p "Enter choice [0-6]: " choice
}

# Parse command line args
case "${1:-}" in
    --github|--gh)
        check_prerequisites
        deploy_via_github_actions
        exit 0
        ;;
    --local)
        check_prerequisites
        bootstrap_terraform_state
        deploy_locally
        exit 0
        ;;
    --bootstrap)
        check_prerequisites
        bootstrap_terraform_state
        exit 0
        ;;
    --secrets)
        setup_github_secrets
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --github, --gh    Deploy via GitHub Actions"
        echo "  --local           Deploy locally with Terraform"
        echo "  --bootstrap       Bootstrap state backend only"
        echo "  --secrets         Setup GitHub secrets only"
        echo "  --help, -h        Show this help"
        echo ""
        echo "Run without options for interactive menu."
        exit 0
        ;;
esac

# Interactive menu
check_prerequisites

while true; do
    show_menu

    case $choice in
        1) deploy_via_github_actions ;;
        2)
            bootstrap_terraform_state
            deploy_locally
            ;;
        3) bootstrap_terraform_state ;;
        4) setup_github_secrets ;;
        5) check_prerequisites ;;
        6) show_outputs ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option" ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
