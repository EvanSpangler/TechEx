# ==========================================
# VPC Outputs
# ==========================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ==========================================
# MongoDB Outputs
# ==========================================

output "mongodb_public_ip" {
  description = "MongoDB VM public IP"
  value       = module.mongodb.public_ip
}

output "mongodb_private_ip" {
  description = "MongoDB VM private IP"
  value       = module.mongodb.private_ip
}

output "mongodb_ssh_key_ssm" {
  description = "SSM parameter for MongoDB SSH key"
  value       = module.mongodb.ssh_private_key_ssm_parameter
}

# ==========================================
# S3 Backup Outputs
# ==========================================

output "backup_bucket_name" {
  description = "S3 backup bucket name (PUBLIC)"
  value       = module.s3_backup.bucket_name
}

output "backup_bucket_url" {
  description = "S3 backup bucket URL"
  value       = "https://${module.s3_backup.bucket_regional_domain_name}"
}

# ==========================================
# EKS Outputs
# ==========================================

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_update_kubeconfig" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# ==========================================
# Application Outputs
# ==========================================

output "app_namespace" {
  description = "Application Kubernetes namespace"
  value       = module.k8s_app.namespace
}

# ==========================================
# Security Outputs
# ==========================================

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

output "cloudtrail_bucket" {
  description = "CloudTrail logs bucket"
  value       = module.security.cloudtrail_bucket_name
}

# ==========================================
# Wazuh Outputs
# ==========================================

output "wazuh_dashboard_url" {
  description = "Wazuh Dashboard URL"
  value       = var.enable_wazuh ? module.wazuh[0].dashboard_url : null
}

output "wazuh_public_ip" {
  description = "Wazuh Manager public IP"
  value       = var.enable_wazuh ? module.wazuh[0].public_ip : null
}

output "wazuh_ssh_key_ssm" {
  description = "SSM parameter for Wazuh SSH key"
  value       = var.enable_wazuh ? module.wazuh[0].ssh_private_key_ssm_parameter : null
}

# ==========================================
# Red Team Outputs
# ==========================================

output "redteam_public_ip" {
  description = "Red Team instance public IP"
  value       = var.enable_redteam ? module.redteam[0].public_ip : null
}

output "redteam_ssh_key_ssm" {
  description = "SSM parameter for Red Team SSH key"
  value       = var.enable_redteam ? module.redteam[0].ssh_private_key_ssm_parameter : null
}

# ==========================================
# Demo Commands
# ==========================================

output "demo_commands" {
  description = "Useful commands for the demo"
  value = <<-EOT

    ========================================
    WIZ EXERCISE - DEMO COMMANDS
    ========================================

    1. Configure kubectl:
       aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}

    2. Get MongoDB SSH key:
       aws ssm get-parameter --name ${module.mongodb.ssh_private_key_ssm_parameter} --with-decryption --query 'Parameter.Value' --output text > mongodb-key.pem
       chmod 600 mongodb-key.pem
       ssh -i mongodb-key.pem ubuntu@${module.mongodb.public_ip}

    3. List public S3 bucket (demonstrates vulnerability):
       aws s3 ls s3://${module.s3_backup.bucket_name} --no-sign-request

    4. Check K8s pods:
       kubectl get pods -n ${module.k8s_app.namespace}

    5. View K8s secrets (demonstrates vulnerability):
       kubectl get secret mongodb-credentials -n ${module.k8s_app.namespace} -o jsonpath='{.data.MONGODB_URI}' | base64 -d

    ${var.enable_wazuh ? "6. Wazuh Dashboard: ${module.wazuh[0].dashboard_url}\n       Username: admin\n" : ""}
    ${var.enable_redteam ? "7. SSH to Red Team:\n       aws ssm get-parameter --name ${module.redteam[0].ssh_private_key_ssm_parameter} --with-decryption --query 'Parameter.Value' --output text > redteam-key.pem\n       chmod 600 redteam-key.pem\n       ssh -i redteam-key.pem ubuntu@${module.redteam[0].public_ip}\n" : ""}
    ========================================
  EOT
}
