# Wiz Technical Exercise - Demo Environment Configuration

# General
aws_region  = "us-east-1"
environment = "wiz-exercise"
owner       = "Evan Spangler"

# VPC
vpc_cidr = "10.0.0.0/16"

# MongoDB
mongodb_instance_type = "t3.medium"
mongodb_admin_user    = "admin"
mongodb_app_user      = "appuser"
mongodb_database      = "tasky"

# EKS
kubernetes_version      = "1.32"
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 2
eks_node_min_size       = 1
eks_node_max_size       = 3

# Application
app_namespace = "tasky"
app_name      = "tasky"
app_replicas  = 2

# NOTE: Set container_image after building and pushing to ECR
container_image = "public.ecr.aws/nginx/nginx:latest"

# Wazuh
enable_wazuh        = true
wazuh_instance_type = "t3.large"

# Red Team
enable_redteam        = true
redteam_instance_type = "t3.medium"

# IMPORTANT: Set these via environment variables or terraform.tfvars.local:
mongodb_admin_pass    = "Sup3rS3cr3t!"
mongodb_app_pass      = "AppS3cr3t!"
backup_encryption_key = "BackupsAreImportant"
wazuh_admin_password  = "SecretPassword"
# wazuh_api_password uses Wazuh default (MyS3cr37P450r.*-) - meets complexity requirements
redteam_allowed_cidrs = ["0.0.0.0/0"]
wazuh_allowed_cidrs   = ["0.0.0.0/0"]
