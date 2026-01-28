# Wiz Technical Exercise - Main Terraform Configuration
# Composes all modules for the two-tier web application

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "wiz-exercise"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Kubernetes provider configured after EKS is created
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

locals {
  tags = {
    Project     = "wiz-exercise"
    Environment = var.environment
    Owner       = var.owner
  }
}

# ==========================================
# VPC Module
# ==========================================
module "vpc" {
  source = "./modules/vpc"

  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  enable_flow_logs = true
  tags             = local.tags
}

# ==========================================
# S3 Backup Module (PUBLIC - Intentional Vulnerability)
# ==========================================
module "s3_backup" {
  source = "./modules/s3-backup"

  environment = var.environment
  tags        = local.tags
}

# ==========================================
# MongoDB VM Module
# ==========================================
module "mongodb" {
  source = "./modules/mongodb-vm"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  private_subnet_cidrs  = module.vpc.private_subnet_cidrs
  instance_type         = var.mongodb_instance_type
  mongodb_admin_user    = var.mongodb_admin_user
  mongodb_admin_pass    = var.mongodb_admin_pass
  mongodb_app_user      = var.mongodb_app_user
  mongodb_app_pass      = var.mongodb_app_pass
  mongodb_database      = var.mongodb_database
  backup_bucket_name    = module.s3_backup.bucket_name
  backup_bucket_arn     = module.s3_backup.bucket_arn
  backup_encryption_key = var.backup_encryption_key
  tags                  = local.tags
}

# ==========================================
# EKS Module
# ==========================================
module "eks" {
  source = "./modules/eks"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kubernetes_version = var.kubernetes_version
  node_instance_types = var.eks_node_instance_types
  node_desired_size  = var.eks_node_desired_size
  node_min_size      = var.eks_node_min_size
  node_max_size      = var.eks_node_max_size
  tags               = local.tags
}

# ==========================================
# K8s Application Module
# ==========================================
module "k8s_app" {
  source = "./modules/k8s-app"

  environment     = var.environment
  namespace       = var.app_namespace
  app_name        = var.app_name
  container_image = var.container_image
  replicas        = var.app_replicas
  mongodb_uri     = module.mongodb.mongodb_connection_string
  jwt_secret      = var.jwt_secret

  depends_on = [module.eks]
}

# ==========================================
# Security Controls Module
# ==========================================
module "security" {
  source = "./modules/security"

  environment = var.environment
  tags        = local.tags
}

# ==========================================
# Wazuh Module (Optional)
# ==========================================
module "wazuh" {
  source = "./modules/wazuh"
  count  = var.enable_wazuh ? 1 : 0

  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = module.vpc.vpc_cidr
  public_subnet_id     = module.vpc.public_subnet_ids[0]
  allowed_cidrs        = var.wazuh_allowed_cidrs
  instance_type        = var.wazuh_instance_type
  wazuh_admin_password = var.wazuh_admin_password
  wazuh_api_password   = var.wazuh_api_password
  tags                 = local.tags
}

# ==========================================
# Red Team Module (Optional)
# ==========================================
module "redteam" {
  source = "./modules/redteam"
  count  = var.enable_redteam ? 1 : 0

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  allowed_cidrs      = var.redteam_allowed_cidrs
  instance_type      = var.redteam_instance_type
  mongodb_private_ip = module.mongodb.private_ip
  eks_cluster_name   = module.eks.cluster_name
  backup_bucket_name = module.s3_backup.bucket_name
  aws_region         = var.aws_region
  tags               = local.tags
}
