output "instance_id" {
  description = "Red Team EC2 instance ID"
  value       = aws_instance.redteam.id
}

output "public_ip" {
  description = "Red Team public IP"
  value       = aws_instance.redteam.public_ip
}

output "private_ip" {
  description = "Red Team private IP"
  value       = aws_instance.redteam.private_ip
}

output "security_group_id" {
  description = "Red Team security group ID"
  value       = aws_security_group.redteam.id
}

output "ssh_key_name" {
  description = "SSH key pair name"
  value       = aws_key_pair.redteam.key_name
}

output "ssh_private_key_ssm_parameter" {
  description = "SSM parameter name for SSH private key"
  value       = aws_ssm_parameter.redteam_private_key.name
}
