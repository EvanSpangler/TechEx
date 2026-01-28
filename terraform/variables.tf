# ==========================================
# General Variables
# ==========================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "wiz-exercise"
}

variable "owner" {
  description = "Owner name for tagging"
  type        = string
  default     = "Evan Spangler"
}

# ==========================================
# VPC Variables
# ==========================================

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# ==========================================
# MongoDB Variables
# ==========================================

variable "mongodb_instance_type" {
  description = "MongoDB EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "mongodb_admin_user" {
  description = "MongoDB admin username"
  type        = string
  default     = "admin"
}

variable "mongodb_admin_pass" {
  description = "MongoDB admin password"
  type        = string
  sensitive   = true
}

variable "mongodb_app_user" {
  description = "MongoDB application username"
  type        = string
  default     = "appuser"
}

variable "mongodb_app_pass" {
  description = "MongoDB application password"
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "MongoDB database name"
  type        = string
  default     = "tasky"
}

variable "backup_encryption_key" {
  description = "GPG passphrase for backup encryption"
  type        = string
  sensitive   = true
  default     = ""
}

# ==========================================
# EKS Variables
# ==========================================

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = "EKS node instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 3
}

# ==========================================
# Application Variables
# ==========================================

variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "tasky"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "tasky"
}

variable "container_image" {
  description = "Container image for the application"
  type        = string
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 2
}

variable "jwt_secret" {
  description = "JWT secret for the application"
  type        = string
  sensitive   = true
  default     = "wiz-exercise-jwt-secret-2024"
}

# ==========================================
# Wazuh Variables
# ==========================================

variable "enable_wazuh" {
  description = "Enable Wazuh deployment"
  type        = bool
  default     = true
}

variable "wazuh_instance_type" {
  description = "Wazuh EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "wazuh_allowed_cidrs" {
  description = "CIDRs allowed to access Wazuh"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "wazuh_admin_password" {
  description = "Wazuh admin password"
  type        = string
  sensitive   = true
  default     = "WazuhAdmin123!"
}

variable "wazuh_api_password" {
  description = "Wazuh API password"
  type        = string
  sensitive   = true
  default     = "WazuhAPI123!"
}

# ==========================================
# Red Team Variables
# ==========================================

variable "enable_redteam" {
  description = "Enable Red Team instance"
  type        = bool
  default     = true
}

variable "redteam_instance_type" {
  description = "Red Team EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "redteam_allowed_cidrs" {
  description = "CIDRs allowed to SSH to Red Team instance"
  type        = list(string)
}
