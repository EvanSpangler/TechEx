# Wiz Technical Exercise - Makefile
# Usage: make [target]

.PHONY: help build deploy destroy reset demo clean bootstrap secrets init plan apply outputs \
        demo-s3 demo-ssh demo-iam demo-k8s demo-secrets demo-redteam demo-wazuh demo-attack \
        show status logs watch

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
	@echo ""
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)           WIZ TECHNICAL EXERCISE - MAKEFILE                   $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)BUILD & DEPLOY:$(NC)"
	@echo "  make build          Deploy via GitHub Actions (recommended)"
	@echo "  make deploy-local   Deploy locally with Terraform"
	@echo "  make bootstrap      Create S3 state backend"
	@echo "  make secrets        Setup GitHub secrets"
	@echo "  make init           Terraform init"
	@echo "  make plan           Terraform plan"
	@echo "  make apply          Terraform apply"
	@echo ""
	@echo "$(RED)DESTROY & RESET:$(NC)"
	@echo "  make destroy        Destroy via GitHub Actions"
	@echo "  make destroy-local  Destroy locally with Terraform"
	@echo "  make reset          Full reset (destroy + clean)"
	@echo "  make clean          Remove local Terraform files"
	@echo "  make force-destroy  Emergency force cleanup"
	@echo ""
	@echo "$(YELLOW)DEMOS:$(NC)"
	@echo "  make demo           Interactive demo menu"
	@echo "  make demo-s3        Public S3 bucket access"
	@echo "  make demo-ssh       SSH to MongoDB"
	@echo "  make demo-iam       Overprivileged IAM"
	@echo "  make demo-k8s       K8s cluster-admin"
	@echo "  make demo-secrets   K8s secrets exposure"
	@echo "  make demo-redteam   SSH to red team instance"
	@echo "  make demo-wazuh     Open Wazuh dashboard"
	@echo "  make demo-attack    Full attack chain"
	@echo ""
	@echo "$(BLUE)STATUS & INFO:$(NC)"
	@echo "  make show           Show all infrastructure"
	@echo "  make status         Show deployment status"
	@echo "  make outputs        Show Terraform outputs"
	@echo "  make logs           Show latest workflow logs"
	@echo "  make watch          Watch running workflow"
	@echo ""

#═══════════════════════════════════════════════════════════════
# BUILD & DEPLOY
#═══════════════════════════════════════════════════════════════

build: ## Deploy via GitHub Actions
	@echo "$(GREEN)Deploying via GitHub Actions...$(NC)"
	@gh workflow run "Deploy Infrastructure" --field action=apply
	@sleep 5
	@$(MAKE) watch

deploy: build

deploy-local: init ## Deploy locally with Terraform
	@echo "$(GREEN)Deploying locally...$(NC)"
	@cd $(TF_DIR) && terraform apply -var-file="environments/demo.tfvars" -auto-approve
	@$(MAKE) outputs

bootstrap: ## Create S3 state backend
	@echo "$(GREEN)Bootstrapping Terraform state backend...$(NC)"
	@cd $(BOOTSTRAP_DIR) && terraform init && terraform apply -auto-approve

secrets: ## Setup GitHub secrets
	@echo "$(GREEN)Setting up GitHub secrets...$(NC)"
	@gh secret set AWS_ACCESS_KEY_ID --body "$$AWS_ACCESS_KEY_ID"
	@gh secret set AWS_SECRET_ACCESS_KEY --body "$$AWS_SECRET_ACCESS_KEY"
	@gh secret set MONGODB_ADMIN_PASS --body "$${MONGODB_ADMIN_PASS:-$$(openssl rand -base64 16)}"
	@gh secret set MONGODB_APP_PASS --body "$${MONGODB_APP_PASS:-$$(openssl rand -base64 16)}"
	@gh secret set BACKUP_ENCRYPTION_KEY --body "$${BACKUP_ENCRYPTION_KEY:-$$(openssl rand -base64 32)}"
	@gh secret set WAZUH_ADMIN_PASS --body "$${WAZUH_ADMIN_PASS:-$$(openssl rand -base64 16)}"
	@gh secret set WAZUH_API_PASS --body "$${WAZUH_API_PASS:-$$(openssl rand -base64 16)}"
	@echo "$(GREEN)Secrets configured!$(NC)"

init: ## Terraform init
	@cd $(TF_DIR) && terraform init

plan: init ## Terraform plan
	@cd $(TF_DIR) && terraform plan -var-file="environments/demo.tfvars"

apply: init ## Terraform apply
	@cd $(TF_DIR) && terraform apply -var-file="environments/demo.tfvars"

#═══════════════════════════════════════════════════════════════
# DESTROY & RESET
#═══════════════════════════════════════════════════════════════

destroy: ## Destroy via GitHub Actions
	@echo "$(RED)Destroying infrastructure via GitHub Actions...$(NC)"
	@read -p "Type DESTROY to confirm: " confirm && [ "$$confirm" = "DESTROY" ] || exit 1
	@gh workflow run "Deploy Infrastructure" --field action=destroy
	@sleep 5
	@$(MAKE) watch

destroy-local: ## Destroy locally with Terraform
	@echo "$(RED)Destroying infrastructure locally...$(NC)"
	@read -p "Type DESTROY to confirm: " confirm && [ "$$confirm" = "DESTROY" ] || exit 1
	@cd $(TF_DIR) && terraform destroy -var-file="environments/demo.tfvars" -auto-approve

reset: destroy clean ## Full reset (destroy + clean)
	@echo "$(GREEN)Reset complete!$(NC)"

clean: ## Remove local Terraform files
	@echo "$(YELLOW)Cleaning local files...$(NC)"
	@rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl
	@rm -f $(TF_DIR)/tfplan* $(TF_DIR)/terraform.tfstate*
	@rm -rf $(BOOTSTRAP_DIR)/.terraform $(BOOTSTRAP_DIR)/.terraform.lock.hcl
	@rm -f /tmp/mongodb-key.pem /tmp/wazuh-key.pem /tmp/redteam-key.pem
	@echo "$(GREEN)Clean complete!$(NC)"

force-destroy: ## Emergency force cleanup
	@echo "$(RED)EMERGENCY FORCE CLEANUP$(NC)"
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
	@echo "$(YELLOW)Force cleanup initiated. Resources may take time to delete.$(NC)"

#═══════════════════════════════════════════════════════════════
# DEMOS
#═══════════════════════════════════════════════════════════════

demo: ## Interactive demo menu
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)                  VULNERABILITY DEMOS                          $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "  1) make demo-s3       - Public S3 bucket access"
	@echo "  2) make demo-ssh      - SSH to exposed MongoDB"
	@echo "  3) make demo-iam      - Overprivileged IAM role"
	@echo "  4) make demo-k8s      - K8s cluster-admin abuse"
	@echo "  5) make demo-secrets  - K8s secrets exposure"
	@echo "  6) make demo-redteam  - SSH to red team instance"
	@echo "  7) make demo-wazuh    - Wazuh SIEM dashboard"
	@echo "  8) make demo-attack   - Full attack chain"
	@echo ""

demo-s3: ## Demo: Public S3 bucket access
	@echo "$(RED)[VULNERABILITY] S3 bucket publicly accessible$(NC)"
	@BUCKET=$$(cd $(TF_DIR) && terraform output -raw backup_bucket_name 2>/dev/null) && \
	echo "$(YELLOW)Listing bucket without authentication:$(NC)" && \
	echo "aws s3 ls s3://$$BUCKET --no-sign-request" && \
	aws s3 ls s3://$$BUCKET --no-sign-request && \
	echo "" && \
	echo "$(YELLOW)Reading file from public bucket:$(NC)" && \
	aws s3 cp s3://$$BUCKET/README.txt - --no-sign-request 2>/dev/null || true

demo-ssh: ## Demo: SSH to MongoDB
	@echo "$(RED)[VULNERABILITY] MongoDB SSH exposed to internet$(NC)"
	@IP=$$(cd $(TF_DIR) && terraform output -raw mongodb_public_ip 2>/dev/null) && \
	KEY=$$(cd $(TF_DIR) && terraform output -raw mongodb_ssh_key_ssm 2>/dev/null) && \
	echo "MongoDB IP: $$IP" && \
	echo "$(YELLOW)Getting SSH key and connecting...$(NC)" && \
	aws ssm get-parameter --name $$KEY --with-decryption --query 'Parameter.Value' --output text --region $(AWS_REGION) > /tmp/mongodb-key.pem && \
	chmod 600 /tmp/mongodb-key.pem && \
	ssh -o StrictHostKeyChecking=no -i /tmp/mongodb-key.pem ubuntu@$$IP

demo-iam: ## Demo: Overprivileged IAM role
	@echo "$(RED)[VULNERABILITY] MongoDB has overprivileged IAM role$(NC)"
	@echo ""
	@echo "The MongoDB instance role has these dangerous permissions:"
	@echo "  - s3:* on all resources"
	@echo "  - ec2:Describe* on all resources"
	@echo "  - iam:Get*, iam:List* on all resources"
	@echo "  - secretsmanager:GetSecretValue on all resources"
	@echo ""
	@echo "$(YELLOW)From MongoDB instance, attacker can run:$(NC)"
	@echo "  aws s3 ls"
	@echo "  aws ec2 describe-instances"
	@echo "  aws iam list-users"
	@echo "  aws secretsmanager list-secrets"

demo-k8s: ## Demo: K8s cluster-admin ServiceAccount
	@echo "$(RED)[VULNERABILITY] App ServiceAccount has cluster-admin$(NC)"
	@aws eks update-kubeconfig --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null
	@echo ""
	@echo "$(YELLOW)ClusterRoleBinding:$(NC)"
	@kubectl get clusterrolebinding tasky-cluster-admin -o yaml | head -25
	@echo ""
	@echo "$(YELLOW)Any pod in tasky namespace can:$(NC)"
	@echo "  - Access secrets in ALL namespaces"
	@echo "  - Create/delete any resource"
	@echo "  - Deploy malicious workloads"

demo-secrets: ## Demo: K8s secrets exposure
	@echo "$(RED)[VULNERABILITY] Secrets stored as base64 (not encrypted)$(NC)"
	@aws eks update-kubeconfig --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null
	@echo ""
	@echo "$(YELLOW)Secrets in tasky namespace:$(NC)"
	@kubectl get secrets -n tasky
	@echo ""
	@echo "$(YELLOW)Decoded MongoDB URI:$(NC)"
	@kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.MONGODB_URI}' | base64 -d && echo ""
	@echo ""
	@echo "$(YELLOW)Decoded JWT Secret:$(NC)"
	@kubectl get secret mongodb-credentials -n tasky -o jsonpath='{.data.SECRET_KEY}' | base64 -d && echo ""

demo-redteam: ## Demo: SSH to red team instance
	@echo "$(GREEN)Red Team Instance - Pre-installed attack tools$(NC)"
	@IP=$$(cd $(TF_DIR) && terraform output -raw redteam_public_ip 2>/dev/null) && \
	KEY=$$(cd $(TF_DIR) && terraform output -raw redteam_ssh_key_ssm 2>/dev/null) && \
	echo "Red Team IP: $$IP" && \
	echo "$(YELLOW)Connecting...$(NC)" && \
	aws ssm get-parameter --name $$KEY --with-decryption --query 'Parameter.Value' --output text --region $(AWS_REGION) > /tmp/redteam-key.pem && \
	chmod 600 /tmp/redteam-key.pem && \
	ssh -o StrictHostKeyChecking=no -i /tmp/redteam-key.pem ubuntu@$$IP

demo-wazuh: ## Demo: Open Wazuh dashboard
	@echo "$(GREEN)Wazuh SIEM Dashboard$(NC)"
	@IP=$$(cd $(TF_DIR) && terraform output -raw wazuh_public_ip 2>/dev/null) && \
	echo "URL: https://$$IP" && \
	echo "Username: admin" && \
	echo "" && \
	xdg-open "https://$$IP" 2>/dev/null || open "https://$$IP" 2>/dev/null || echo "Open https://$$IP in browser"

demo-attack: ## Demo: Full attack chain walkthrough
	@echo "$(RED)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(RED)                    FULL ATTACK CHAIN                          $(NC)"
	@echo "$(RED)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(RED)Step 1: Discover public S3 bucket$(NC)"
	@echo "  - Find publicly accessible backup bucket"
	@echo "  - Download sensitive data/credentials"
	@echo ""
	@echo "$(RED)Step 2: SSH to MongoDB (port 22 exposed)$(NC)"
	@echo "  - Scan for open SSH ports"
	@echo "  - Exploit weak credentials or CVEs"
	@echo ""
	@echo "$(RED)Step 3: Abuse overprivileged IAM role$(NC)"
	@echo "  - Use instance role to access AWS APIs"
	@echo "  - Enumerate S3, EC2, IAM, Secrets Manager"
	@echo ""
	@echo "$(RED)Step 4: Access EKS cluster$(NC)"
	@echo "  - Use discovered credentials for K8s"
	@echo "  - ServiceAccount has cluster-admin"
	@echo ""
	@echo "$(RED)Step 5: Full cluster takeover$(NC)"
	@echo "  - Access all secrets across namespaces"
	@echo "  - Deploy cryptominers/backdoors"
	@echo "  - Pivot to other AWS resources"
	@echo ""

#═══════════════════════════════════════════════════════════════
# STATUS & INFO
#═══════════════════════════════════════════════════════════════

show: ## Show all infrastructure
	@echo "$(BLUE)EC2 Instances:$(NC)"
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=wiz-exercise" \
		--query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,PublicIP:PublicIpAddress}' \
		--output table --region $(AWS_REGION) 2>/dev/null || echo "  None"
	@echo ""
	@echo "$(BLUE)S3 Buckets:$(NC)"
	@aws s3 ls --region $(AWS_REGION) 2>/dev/null | grep wiz || echo "  None"
	@echo ""
	@echo "$(BLUE)EKS Cluster:$(NC)"
	@aws eks describe-cluster --name wiz-exercise-eks --region $(AWS_REGION) \
		--query 'cluster.{name:name,status:status,version:version}' --output table 2>/dev/null || echo "  None"
	@echo ""
	@echo "$(BLUE)K8s Pods:$(NC)"
	@aws eks update-kubeconfig --name wiz-exercise-eks --region $(AWS_REGION) 2>/dev/null && \
		kubectl get pods -A 2>/dev/null || echo "  None"

status: ## Show deployment status
	@echo "$(BLUE)Latest GitHub Actions runs:$(NC)"
	@gh run list --workflow="Deploy Infrastructure" --limit 5

outputs: ## Show Terraform outputs
	@cd $(TF_DIR) && terraform output

logs: ## Show latest workflow logs
	@RUN_ID=$$(gh run list --workflow="Deploy Infrastructure" --limit 1 --json databaseId --jq '.[0].databaseId') && \
	gh run view $$RUN_ID --log

watch: ## Watch running workflow
	@RUN_ID=$$(gh run list --workflow="Deploy Infrastructure" --limit 1 --json databaseId --jq '.[0].databaseId') && \
	gh run watch $$RUN_ID
