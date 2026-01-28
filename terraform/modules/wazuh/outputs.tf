output "instance_id" {
  description = "Wazuh Manager EC2 instance ID"
  value       = aws_instance.wazuh.id
}

output "public_ip" {
  description = "Wazuh Manager public IP"
  value       = aws_instance.wazuh.public_ip
}

output "private_ip" {
  description = "Wazuh Manager private IP"
  value       = aws_instance.wazuh.private_ip
}

output "dashboard_url" {
  description = "Wazuh Dashboard URL"
  value       = "https://${aws_instance.wazuh.public_ip}"
}

output "security_group_id" {
  description = "Wazuh security group ID"
  value       = aws_security_group.wazuh.id
}

output "ssh_key_name" {
  description = "SSH key pair name"
  value       = aws_key_pair.wazuh.key_name
}

output "ssh_private_key_ssm_parameter" {
  description = "SSM parameter name for SSH private key"
  value       = aws_ssm_parameter.wazuh_private_key.name
}
