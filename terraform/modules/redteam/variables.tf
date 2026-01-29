variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID"
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to SSH"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "mongodb_private_ip" {
  description = "MongoDB VM private IP"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "backup_bucket_name" {
  description = "S3 backup bucket name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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
