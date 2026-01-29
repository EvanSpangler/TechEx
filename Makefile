# Wiz Technical Exercise - Makefile
# Usage: make [target]

.PHONY: help build deploy destroy reset demo clean bootstrap secrets init plan apply outputs \
        demo-s3 demo-ssh demo-iam demo-k8s demo-secrets demo-redteam demo-wazuh demo-attack \
        show status logs watch ssh-keys ssh-info ssh-mongodb ssh-wazuh ssh-redteam \
        docs docs-serve docs-build test test-terraform test-lint test-security test-all

# Configuration
SHELL := /bin/bash
AWS_REGION ?= us-east-1
TF_DIR := terraform
BOOTSTRAP_DIR := terraform/bootstrap
ENV_FILE := .env

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Load environment
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
    export
endif

# Default target
help:
	@printf "\n"
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(BLUE)           WIZ TECHNICAL EXERCISE - MAKEFILE                   $(NC)\n"
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"
	@printf "$(GREEN)BUILD & DEPLOY:$(NC)\n"
	@printf "  make build          Deploy via GitHub Actions (recommended)\n"
	@printf "  make deploy-local   Deploy locally with Terraform\n"
	@printf "  make bootstrap      Create S3 state backend\n"
	@printf "  make secrets        Setup GitHub secrets\n"
	@printf "  make init           Terraform init\n"
	@printf "  make plan           Terraform plan\n"
	@printf "  make apply          Terraform apply\n"
	@printf "\n"
	@printf "$(GREEN)SSH ACCESS:$(NC)\n"
	@printf "  make ssh-keys       Fetch and store SSH keys locally\n"
	@printf "  make ssh-info       Show SSH connection commands\n"
	@printf "  make ssh-mongodb    SSH to MongoDB instance\n"
	@printf "  make ssh-wazuh      SSH to Wazuh instance\n"
	@printf "  make ssh-redteam    SSH to Red Team instance\n"
	@printf "\n"
	@printf "$(RED)DESTROY & RESET:$(NC)\n"
	@printf "  make destroy        Destroy via GitHub Actions\n"
	@printf "  make destroy-local  Destroy locally with Terraform\n"
	@printf "  make reset          Full reset (destroy + clean)\n"
	@printf "  make clean          Remove local Terraform files\n"
	@printf "  make force-destroy  Emergency force cleanup\n"
	@printf "\n"
	@printf "$(YELLOW)DEMOS:$(NC)\n"
	@printf "  make demo           Interactive demo menu\n"
	@printf "  make demo-s3        Public S3 bucket access\n"
	@printf "  make demo-ssh       SSH to MongoDB\n"
	@printf "  make demo-iam       Overprivileged IAM\n"
	@printf "  make demo-k8s       K8s cluster-admin\n"
	@printf "  make demo-secrets   K8s secrets exposure\n"
	@printf "  make demo-redteam   SSH to red team instance\n"
	@printf "  make demo-wazuh     Open Wazuh dashboard\n"
	@printf "  make demo-attack    Full attack chain\n"
	@printf "\n"
	@printf "$(BLUE)STATUS & INFO:$(NC)\n"
	@printf "  make show           Show all infrastructure\n"
	@printf "  make status         Show deployment status\n"
	@printf "  make outputs        Show Terraform outputs\n"
	@printf "  make logs           Show latest workflow logs\n"
	@printf "  make watch          Watch running workflow\n"
	@printf "\n"
	@printf "$(BLUE)DOCUMENTATION:$(NC)\n"
	@printf "  make docs           Serve documentation locally\n"
	@printf "  make docs-build     Build documentation for production\n"
	@printf "  make docs-deploy    Deploy docs to GitHub Pages\n"
	@printf "\n"
	@printf "$(BLUE)TESTING:$(NC)\n"
	@printf "  make test           Run all tests\n"
	@printf "  make test-lint      Run linting checks\n"
	@printf "  make test-terraform Validate Terraform\n"
	@printf "  make test-security  Run security scans\n"
	@printf "  make test-docs      Validate documentation\n"
	@printf "  make test-container Build and scan container\n"
	@printf "  make check-prereqs  Check all prerequisites\n"
	@printf "\n"

#═══════════════════════════════════════════════════════════════
# BUILD & DEPLOY
#═══════════════════════════════════════════════════════════════

build: ## Deploy via GitHub Actions
	@printf "$(GREEN)Deploying via GitHub Actions...$(NC)\n"
	@gh workflow run "Deploy Infrastructure" --field action=apply
	@sleep 5
	@$(MAKE) watch
	@$(MAKE) ssh-keys

deploy: build

deploy-local: init ## Deploy locally with Terraform
	@printf "$(GREEN)Deploying locally...$(NC)\n"
	@cd $(TF_DIR) && terraform apply -var-file="environments/demo.tfvars" -auto-approve
	@$(MAKE) ssh-keys

bootstrap: ## Create S3 state backend
	@printf "$(GREEN)Bootstrapping Terraform state backend...$(NC)\n"
	@cd $(BOOTSTRAP_DIR) && terraform init && terraform apply -auto-approve

secrets: ## Setup GitHub secrets
	@printf "$(GREEN)Setting up GitHub secrets...$(NC)\n"
	@gh secret set AWS_ACCESS_KEY_ID --body "$$AWS_ACCESS_KEY_ID"
	@gh secret set AWS_SECRET_ACCESS_KEY --body "$$AWS_SECRET_ACCESS_KEY"
	@gh secret set MONGODB_ADMIN_PASS --body "$${MONGODB_ADMIN_PASS:-$$(openssl rand -base64 16)}"
	@gh secret set MONGODB_APP_PASS --body "$${MONGODB_APP_PASS:-$$(openssl rand -base64 16)}"
	@gh secret set BACKUP_ENCRYPTION_KEY --body "$${BACKUP_ENCRYPTION_KEY:-$$(openssl rand -base64 32)}"
	@gh secret set WAZUH_ADMIN_PASS --body "$${WAZUH_ADMIN_PASS:-$$(openssl rand -base64 16)}"
	@gh secret set WAZUH_API_PASS --body "$${WAZUH_API_PASS:-$$(openssl rand -base64 16)}"
	@printf "$(GREEN)Secrets configured!$(NC)\n"

init: ## Terraform init
	@cd $(TF_DIR) && terraform init

plan: init ## Terraform plan
	@cd $(TF_DIR) && terraform plan -var-file="environments/demo.tfvars"

apply: init ## Terraform apply
	@cd $(TF_DIR) && terraform apply -var-file="environments/demo.tfvars"
	@$(MAKE) ssh-keys

ssh-keys: ## Fetch and store SSH keys locally
	@printf "$(GREEN)Fetching SSH keys from AWS SSM...$(NC)\n"
	@mkdir -p keys
	@# MongoDB key
	@bash -c 'source $(ENV_FILE) 2>/dev/null; \
		aws ssm get-parameter --name /wiz-exercise/mongodb/ssh-private-key \
		--with-decryption --query "Parameter.Value" --output text \
		--region $(AWS_REGION) > keys/mongodb.pem 2>/dev/null && \
		chmod 600 keys/mongodb.pem && \
		printf "$(GREEN)[OK]$(NC) keys/mongodb.pem\n" || \
		printf "$(YELLOW)[SKIP]$(NC) MongoDB key not available\n"'
	@# Wazuh key
	@bash -c 'source $(ENV_FILE) 2>/dev/null; \
		aws ssm get-parameter --name /wiz-exercise/wazuh/ssh-private-key \
		--with-decryption --query "Parameter.Value" --output text \
		--region $(AWS_REGION) > keys/wazuh.pem 2>/dev/null && \
		chmod 600 keys/wazuh.pem && \
		printf "$(GREEN)[OK]$(NC) keys/wazuh.pem\n" || \
		printf "$(YELLOW)[SKIP]$(NC) Wazuh key not available\n"'
	@# Red Team key
	@bash -c 'source $(ENV_FILE) 2>/dev/null; \
		aws ssm get-parameter --name /wiz-exercise/redteam/ssh-private-key \
		--with-decryption --query "Parameter.Value" --output text \
		--region $(AWS_REGION) > keys/redteam.pem 2>/dev/null && \
		chmod 600 keys/redteam.pem && \
		printf "$(GREEN)[OK]$(NC) keys/redteam.pem\n" || \
		printf "$(YELLOW)[SKIP]$(NC) Red Team key not available\n"'
	@printf "\n"
	@$(MAKE) ssh-info

ssh-info: ## Show SSH connection commands
	@printf "\n"
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(BLUE)                    SSH CONNECTION INFO                         $(NC)\n"
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"
	@cd $(TF_DIR) && \
	MONGODB_IP=$$(terraform output -raw mongodb_public_ip 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
	WAZUH_IP=$$(terraform output -raw wazuh_public_ip 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
	REDTEAM_IP=$$(terraform output -raw redteam_public_ip 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
	if [ -n "$$MONGODB_IP" ]; then \
		printf "$(GREEN)MongoDB:$(NC)    ssh -i keys/mongodb.pem ubuntu@$$MONGODB_IP\n"; \
		printf "$(GREEN)Wazuh:$(NC)      ssh -i keys/wazuh.pem ubuntu@$$WAZUH_IP\n"; \
		printf "$(GREEN)Dashboard:$(NC)  https://$$WAZUH_IP (user: admin)\n"; \
		printf "$(GREEN)Red Team:$(NC)   ssh -i keys/redteam.pem ubuntu@$$REDTEAM_IP\n"; \
	else \
		printf "$(YELLOW)No infrastructure deployed. Run 'make build' first.$(NC)\n"; \
	fi
	@printf "\n"
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"

ssh-mongodb: ## SSH to MongoDB instance
	@test -f keys/mongodb.pem || $(MAKE) ssh-keys
	@IP=$$(cd $(TF_DIR) && terraform output -raw mongodb_public_ip 2>/dev/null) && \
	ssh -o StrictHostKeyChecking=no -i keys/mongodb.pem ubuntu@$$IP

ssh-wazuh: ## SSH to Wazuh instance
	@test -f keys/wazuh.pem || $(MAKE) ssh-keys
	@IP=$$(cd $(TF_DIR) && terraform output -raw wazuh_public_ip 2>/dev/null) && \
	ssh -o StrictHostKeyChecking=no -i keys/wazuh.pem ubuntu@$$IP

ssh-redteam: ## SSH to Red Team instance
	@test -f keys/redteam.pem || $(MAKE) ssh-keys
	@IP=$$(cd $(TF_DIR) && terraform output -raw redteam_public_ip 2>/dev/null) && \
	ssh -o StrictHostKeyChecking=no -i keys/redteam.pem ubuntu@$$IP

#═══════════════════════════════════════════════════════════════
# DESTROY & RESET
#═══════════════════════════════════════════════════════════════

destroy: ## Destroy via GitHub Actions
	@printf "$(RED)Destroying infrastructure via GitHub Actions...$(NC)\n"
	@read -p "Type DESTROY to confirm: " confirm && [ "$$confirm" = "DESTROY" ] || exit 1
	@gh workflow run "Deploy Infrastructure" --field action=destroy
	@sleep 5
	@$(MAKE) watch

destroy-local: ## Destroy locally with Terraform
	@printf "$(RED)Destroying infrastructure locally...$(NC)\n"
	@read -p "Type DESTROY to confirm: " confirm && [ "$$confirm" = "DESTROY" ] || exit 1
	@cd $(TF_DIR) && terraform destroy -var-file="environments/demo.tfvars" -auto-approve

reset: destroy clean ## Full reset (destroy + clean)
	@printf "$(GREEN)Reset complete!$(NC)\n"

clean: ## Remove local Terraform files and keys
	@printf "$(YELLOW)Cleaning local files...$(NC)\n"
	@rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl
	@rm -f $(TF_DIR)/tfplan* $(TF_DIR)/terraform.tfstate*
	@rm -rf $(BOOTSTRAP_DIR)/.terraform $(BOOTSTRAP_DIR)/.terraform.lock.hcl
	@rm -rf keys/
	@printf "$(GREEN)Clean complete!$(NC)\n"

force-destroy: ## Emergency force cleanup
	@printf "$(RED)EMERGENCY FORCE CLEANUP$(NC)\n"
	@read -p "Type FORCE to confirm: " confirm && [ "$$confirm" = "FORCE" ] || exit 1
	@# Terminate EC2
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=wiz-exercise" \
		--query 'Reservations[*].Instances[*].InstanceId' --output text --region $(AWS_REGION) | \
		xargs -r aws ec2 terminate-instances --instance-ids --region $(AWS_REGION) || true
	@# Delete EKS
	@aws eks delete-nodegroup --cluster-name wiz-exercise-eks --nodegroup-name wiz-exercise-eks-nodes --region $(AWS_REGION) 2>/dev/null || true
	@aws eks delete-cluster --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null || true
	@# Delete S3
	@for b in $$(aws s3 ls | grep wiz-exercise | awk '{print $$3}'); do \
		aws s3 rm s3://$$b --recursive --region $(AWS_REGION) 2>/dev/null || true; \
		aws s3 rb s3://$$b --force --region $(AWS_REGION) 2>/dev/null || true; \
	done
	@printf "$(YELLOW)Force cleanup initiated. Resources may take time to delete.$(NC)\n"

#═══════════════════════════════════════════════════════════════
# DEMOS
#═══════════════════════════════════════════════════════════════

demo: ## Interactive demo menu
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(BLUE)                  VULNERABILITY DEMOS                          $(NC)\n"
	@printf "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"
	@printf "  1) make demo-s3       - Public S3 bucket access\n"
	@printf "  2) make demo-ssh      - SSH to exposed MongoDB\n"
	@printf "  3) make demo-iam      - Overprivileged IAM role\n"
	@printf "  4) make demo-k8s      - K8s cluster-admin abuse\n"
	@printf "  5) make demo-secrets  - K8s secrets exposure\n"
	@printf "  6) make demo-redteam  - SSH to red team instance\n"
	@printf "  7) make demo-wazuh    - Wazuh SIEM dashboard\n"
	@printf "  8) make demo-attack   - Full attack chain\n"
	@printf "\n"

demo-s3: ## Demo: Public S3 bucket access
	@printf "$(RED)[VULNERABILITY] S3 bucket publicly accessible$(NC)\n"
	@BUCKET=$$(cd $(TF_DIR) && terraform output -raw backup_bucket_name 2>/dev/null) && \
	printf "$(YELLOW)Listing bucket without authentication:$(NC)\n" && \
	printf "aws s3 ls s3://$$BUCKET --no-sign-request\n" && \
	aws s3 ls s3://$$BUCKET --no-sign-request && \
	printf "\n" && \
	printf "$(YELLOW)Reading file from public bucket:$(NC)\n" && \
	aws s3 cp s3://$$BUCKET/README.txt - --no-sign-request 2>/dev/null || true

demo-ssh: ## Demo: SSH to MongoDB
	@printf "$(RED)[VULNERABILITY] MongoDB SSH exposed to internet$(NC)\n"
	@test -f keys/mongodb.pem || $(MAKE) ssh-keys
	@IP=$$(cd $(TF_DIR) && terraform output -raw mongodb_public_ip 2>/dev/null) && \
	printf "MongoDB IP: $$IP\n" && \
	printf "$(YELLOW)Connecting...$(NC)\n" && \
	ssh -o StrictHostKeyChecking=no -i keys/mongodb.pem ubuntu@$$IP

demo-iam: ## Demo: Overprivileged IAM role
	@printf "$(RED)[VULNERABILITY] MongoDB has overprivileged IAM role$(NC)\n"
	@printf "\n"
	@printf "The MongoDB instance role has these dangerous permissions:\n"
	@printf "  - s3:* on all resources\n"
	@printf "  - ec2:Describe* on all resources\n"
	@printf "  - iam:Get*, iam:List* on all resources\n"
	@printf "  - secretsmanager:GetSecretValue on all resources\n"
	@printf "\n"
	@printf "$(YELLOW)From MongoDB instance, attacker can run:$(NC)\n"
	@printf "  aws s3 ls\n"
	@printf "  aws ec2 describe-instances\n"
	@printf "  aws iam list-users\n"
	@printf "  aws secretsmanager list-secrets\n"

demo-k8s: ## Demo: K8s cluster-admin ServiceAccount
	@printf "$(RED)[VULNERABILITY] App ServiceAccount has cluster-admin$(NC)\n"
	@aws eks update-kubeconfig --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null
	@printf "\n"
	@printf "$(YELLOW)ClusterRoleBinding:$(NC)\n"
	@kubectl get clusterrolebinding tasky-cluster-admin -o yaml | head -25
	@printf "\n"
	@printf "$(YELLOW)Any pod in tasky namespace can:$(NC)\n"
	@printf "  - Access secrets in ALL namespaces\n"
	@printf "  - Create/delete any resource\n"
	@printf "  - Deploy malicious workloads\n"

demo-secrets: ## Demo: K8s secrets exposure
	@printf "$(RED)[VULNERABILITY] Secrets stored as base64 (not encrypted)$(NC)\n"
	@aws eks update-kubeconfig --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null
	@printf "\n"
	@printf "$(YELLOW)Secrets in tasky namespace:$(NC)\n"
	@kubectl get secrets -n tasky
	@printf "\n"
	@printf "$(YELLOW)Decoded MongoDB URI:$(NC)\n"
	@kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.MONGODB_URI}' | base64 -d && printf "\n"
	@printf "\n"
	@printf "$(YELLOW)Decoded JWT Secret:$(NC)\n"
	@kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.SECRET_KEY}' | base64 -d && printf "\n"

demo-redteam: ## Demo: SSH to red team instance
	@printf "$(GREEN)Red Team Instance - Pre-installed attack tools$(NC)\n"
	@test -f keys/redteam.pem || $(MAKE) ssh-keys
	@IP=$$(cd $(TF_DIR) && terraform output -raw redteam_public_ip 2>/dev/null) && \
	printf "Red Team IP: $$IP\n" && \
	printf "$(YELLOW)Connecting...$(NC)\n" && \
	ssh -o StrictHostKeyChecking=no -i keys/redteam.pem ubuntu@$$IP

demo-wazuh: ## Demo: Open Wazuh dashboard
	@printf "$(GREEN)Wazuh SIEM Dashboard$(NC)\n"
	@IP=$$(cd $(TF_DIR) && terraform output -raw wazuh_public_ip 2>/dev/null) && \
	printf "URL: https://$$IP\n" && \
	printf "Username: admin\n" && \
	printf "\n" && \
	xdg-open "https://$$IP" 2>/dev/null || open "https://$$IP" 2>/dev/null || printf "Open https://$$IP in browser\n"

demo-attack: ## Demo: Full attack chain walkthrough
	@printf "$(RED)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "$(RED)                    FULL ATTACK CHAIN                          $(NC)\n"
	@printf "$(RED)═══════════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"
	@printf "$(RED)Step 1: Discover public S3 bucket$(NC)\n"
	@printf "  - Find publicly accessible backup bucket\n"
	@printf "  - Download sensitive data/credentials\n"
	@printf "\n"
	@printf "$(RED)Step 2: SSH to MongoDB (port 22 exposed)$(NC)\n"
	@printf "  - Scan for open SSH ports\n"
	@printf "  - Exploit weak credentials or CVEs\n"
	@printf "\n"
	@printf "$(RED)Step 3: Abuse overprivileged IAM role$(NC)\n"
	@printf "  - Use instance role to access AWS APIs\n"
	@printf "  - Enumerate S3, EC2, IAM, Secrets Manager\n"
	@printf "\n"
	@printf "$(RED)Step 4: Access EKS cluster$(NC)\n"
	@printf "  - Use discovered credentials for K8s\n"
	@printf "  - ServiceAccount has cluster-admin\n"
	@printf "\n"
	@printf "$(RED)Step 5: Full cluster takeover$(NC)\n"
	@printf "  - Access all secrets across namespaces\n"
	@printf "  - Deploy cryptominers/backdoors\n"
	@printf "  - Pivot to other AWS resources\n"
	@printf "\n"

#═══════════════════════════════════════════════════════════════
# STATUS & INFO
#═══════════════════════════════════════════════════════════════

show: ## Show all infrastructure
	@printf "$(BLUE)EC2 Instances:$(NC)\n"
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=wiz-exercise" \
		--query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,PublicIP:PublicIpAddress}' \
		--output table --region $(AWS_REGION) 2>/dev/null || printf "  None\n"
	@printf "\n"
	@printf "$(BLUE)S3 Buckets:$(NC)\n"
	@aws s3 ls --region $(AWS_REGION) 2>/dev/null | grep wiz || printf "  None\n"
	@printf "\n"
	@printf "$(BLUE)EKS Cluster:$(NC)\n"
	@aws eks describe-cluster --name wiz-exercise-eks --region $(AWS_REGION) \
		--query 'cluster.{name:name,status:status,version:version}' --output table 2>/dev/null || printf "  None\n"
	@printf "\n"
	@printf "$(BLUE)K8s Pods:$(NC)\n"
	@aws eks update-kubeconfig --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null && \
		kubectl get pods -A 2>/dev/null || printf "  None\n"

status: ## Show deployment status
	@printf "$(BLUE)Latest GitHub Actions runs:$(NC)\n"
	@gh run list --workflow="Deploy Infrastructure" --limit 5

outputs: ## Show Terraform outputs
	@cd $(TF_DIR) && terraform output

logs: ## Show latest workflow logs
	@RUN_ID=$$(gh run list --workflow="Deploy Infrastructure" --limit 1 --json databaseId --jq '.[0].databaseId') && \
	gh run view $$RUN_ID --log

watch: ## Watch running workflow
	@RUN_ID=$$(gh run list --workflow="Deploy Infrastructure" --limit 1 --json databaseId --jq '.[0].databaseId') && \
	gh run watch $$RUN_ID

#═══════════════════════════════════════════════════════════════
# DOCUMENTATION
#═══════════════════════════════════════════════════════════════

docs: docs-serve ## Alias for docs-serve

docs-serve: ## Serve documentation locally (live reload)
	@printf "$(BLUE)Starting MkDocs development server...$(NC)\n"
	@printf "$(GREEN)Documentation: http://127.0.0.1:8000$(NC)\n"
	@mkdocs serve

docs-build: ## Build documentation for production
	@printf "$(BLUE)Building documentation...$(NC)\n"
	@mkdocs build --strict
	@printf "$(GREEN)Documentation built to site/$(NC)\n"

docs-deploy: docs-build ## Deploy documentation to GitHub Pages
	@printf "$(BLUE)Deploying documentation to GitHub Pages...$(NC)\n"
	@mkdocs gh-deploy --force
	@printf "$(GREEN)Documentation deployed!$(NC)\n"

#═══════════════════════════════════════════════════════════════
# TESTING
#═══════════════════════════════════════════════════════════════

test: test-all ## Run all tests

test-all: test-lint test-terraform test-security test-docs ## Run all test suites
	@printf "$(GREEN)All tests passed!$(NC)\n"

test-lint: ## Run linting checks
	@printf "$(BLUE)Running lint checks...$(NC)\n"
	@# Terraform format check
	@printf "$(YELLOW)Checking Terraform formatting...$(NC)\n"
	@cd $(TF_DIR) && terraform fmt -check -recursive && \
		printf "$(GREEN)[PASS]$(NC) Terraform formatting\n" || \
		(printf "$(RED)[FAIL]$(NC) Terraform formatting\n" && exit 1)
	@# YAML lint
	@printf "$(YELLOW)Checking YAML files...$(NC)\n"
	@command -v yamllint >/dev/null 2>&1 && \
		(yamllint -d relaxed .github/ k8s/ mkdocs.yml 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) YAML lint\n") || \
		printf "$(YELLOW)[SKIP]$(NC) yamllint not installed\n"
	@# Markdown lint
	@printf "$(YELLOW)Checking Markdown files...$(NC)\n"
	@command -v markdownlint >/dev/null 2>&1 && \
		(markdownlint docs/ --ignore node_modules 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) Markdown lint\n") || \
		printf "$(YELLOW)[SKIP]$(NC) markdownlint not installed\n"

test-terraform: ## Validate Terraform configuration
	@printf "$(BLUE)Validating Terraform...$(NC)\n"
	@cd $(TF_DIR) && terraform init -backend=false -input=false >/dev/null 2>&1
	@cd $(TF_DIR) && terraform validate && \
		printf "$(GREEN)[PASS]$(NC) Terraform validation\n" || \
		(printf "$(RED)[FAIL]$(NC) Terraform validation\n" && exit 1)

test-security: ## Run security scans
	@printf "$(BLUE)Running security scans...$(NC)\n"
	@# tfsec
	@printf "$(YELLOW)Running tfsec...$(NC)\n"
	@command -v tfsec >/dev/null 2>&1 && \
		(tfsec $(TF_DIR) --soft-fail 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) tfsec scan (findings expected for demo)\n") || \
		printf "$(YELLOW)[SKIP]$(NC) tfsec not installed\n"
	@# checkov
	@printf "$(YELLOW)Running checkov...$(NC)\n"
	@command -v checkov >/dev/null 2>&1 && \
		(checkov -d $(TF_DIR) --soft-fail --quiet 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) checkov scan (findings expected for demo)\n") || \
		printf "$(YELLOW)[SKIP]$(NC) checkov not installed\n"
	@# trivy config scan
	@printf "$(YELLOW)Running trivy config scan...$(NC)\n"
	@command -v trivy >/dev/null 2>&1 && \
		(trivy config $(TF_DIR) --exit-code 0 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) trivy config scan (findings expected for demo)\n") || \
		printf "$(YELLOW)[SKIP]$(NC) trivy not installed\n"

test-docs: ## Validate documentation
	@printf "$(BLUE)Validating documentation...$(NC)\n"
	@# Check mkdocs build
	@printf "$(YELLOW)Building documentation (strict mode)...$(NC)\n"
	@command -v mkdocs >/dev/null 2>&1 && \
		(mkdocs build --strict 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) MkDocs build\n" || \
		(printf "$(RED)[FAIL]$(NC) MkDocs build\n" && exit 1)) || \
		printf "$(YELLOW)[SKIP]$(NC) mkdocs not installed\n"
	@# Check for broken internal links
	@printf "$(YELLOW)Checking documentation links...$(NC)\n"
	@command -v linkchecker >/dev/null 2>&1 && \
		(linkchecker site/ --check-extern=false 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) Link check\n") || \
		printf "$(YELLOW)[SKIP]$(NC) linkchecker not installed\n"

test-k8s: ## Validate Kubernetes manifests
	@printf "$(BLUE)Validating Kubernetes manifests...$(NC)\n"
	@# kubeval
	@command -v kubeval >/dev/null 2>&1 && \
		(kubeval k8s/*.yaml 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) Kubernetes manifest validation\n") || \
		printf "$(YELLOW)[SKIP]$(NC) kubeval not installed\n"
	@# kubeconform
	@command -v kubeconform >/dev/null 2>&1 && \
		(kubeconform -strict k8s/*.yaml 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) kubeconform validation\n") || \
		printf "$(YELLOW)[SKIP]$(NC) kubeconform not installed\n"

test-container: ## Build and scan container image locally
	@printf "$(BLUE)Building and scanning container image...$(NC)\n"
	@cd app && docker build -t wiz-exercise-test:local .
	@printf "$(YELLOW)Verifying wizexercise.txt...$(NC)\n"
	@docker run --rm wiz-exercise-test:local cat /app/wizexercise.txt && \
		printf "$(GREEN)[PASS]$(NC) wizexercise.txt exists\n" || \
		(printf "$(RED)[FAIL]$(NC) wizexercise.txt missing\n" && exit 1)
	@printf "$(YELLOW)Running Trivy scan...$(NC)\n"
	@command -v trivy >/dev/null 2>&1 && \
		(trivy image wiz-exercise-test:local --severity HIGH,CRITICAL 2>/dev/null && \
		printf "$(GREEN)[PASS]$(NC) Container scan complete\n") || \
		printf "$(YELLOW)[SKIP]$(NC) trivy not installed\n"

#═══════════════════════════════════════════════════════════════
# PREREQUISITES CHECK
#═══════════════════════════════════════════════════════════════

check-prereqs: ## Check all prerequisites
	@printf "$(BLUE)Checking prerequisites...$(NC)\n"
	@printf "\n"
	@printf "$(GREEN)Required:$(NC)\n"
	@command -v aws >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) aws-cli\n" || printf "  $(RED)[MISSING]$(NC) aws-cli\n"
	@command -v terraform >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) terraform\n" || printf "  $(RED)[MISSING]$(NC) terraform\n"
	@command -v kubectl >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) kubectl\n" || printf "  $(RED)[MISSING]$(NC) kubectl\n"
	@command -v gh >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) gh (GitHub CLI)\n" || printf "  $(RED)[MISSING]$(NC) gh (GitHub CLI)\n"
	@command -v docker >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) docker\n" || printf "  $(RED)[MISSING]$(NC) docker\n"
	@command -v mkdocs >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) mkdocs\n" || printf "  $(RED)[MISSING]$(NC) mkdocs\n"
	@printf "\n"
	@printf "$(YELLOW)Optional (for testing):$(NC)\n"
	@command -v tfsec >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) tfsec\n" || printf "  $(YELLOW)[MISSING]$(NC) tfsec\n"
	@command -v checkov >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) checkov\n" || printf "  $(YELLOW)[MISSING]$(NC) checkov\n"
	@command -v trivy >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) trivy\n" || printf "  $(YELLOW)[MISSING]$(NC) trivy\n"
	@command -v yamllint >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) yamllint\n" || printf "  $(YELLOW)[MISSING]$(NC) yamllint\n"
	@command -v markdownlint >/dev/null 2>&1 && printf "  $(GREEN)[OK]$(NC) markdownlint\n" || printf "  $(YELLOW)[MISSING]$(NC) markdownlint\n"
	@printf "\n"
