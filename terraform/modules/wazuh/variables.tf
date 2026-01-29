variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for Wazuh Manager"
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to access Wazuh Dashboard"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "wazuh_admin_password" {
  description = "Wazuh admin password"
  type        = string
  sensitive   = true
  default     = "WazuhAdmin123!"
}

variable "wazuh_api_user" {
  description = "Wazuh API user"
  type        = string
  default     = "wazuh-wui"
}

variable "wazuh_api_password" {
  description = "Wazuh API password"
  type        = string
  sensitive   = true
  default     = "WazuhAPI123!"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "cloudtrail_bucket_name" {
  description = "CloudTrail S3 bucket name"
  type        = string
  default     = ""
}

variable "config_bucket_name" {
  description = "AWS Config S3 bucket name"
  type        = string
  default     = ""
}

variable "vpc_flow_logs_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
