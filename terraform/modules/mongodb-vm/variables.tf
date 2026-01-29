variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for MongoDB VM"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for MongoDB access"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
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

variable "backup_bucket_name" {
  description = "S3 bucket name for backups"
  type        = string
}

variable "backup_bucket_arn" {
  description = "S3 bucket ARN for backups"
  type        = string
}

variable "backup_encryption_key" {
  description = "GPG passphrase for backup encryption"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_wazuh_agent" {
  description = "Enable Wazuh agent installation"
  type        = bool
  default     = false
}

variable "wazuh_manager_ip" {
  description = "Wazuh Manager private IP for agent registration"
  type        = string
  default     = ""
}
