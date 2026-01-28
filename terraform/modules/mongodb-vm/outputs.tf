output "instance_id" {
  description = "MongoDB EC2 instance ID"
  value       = aws_instance.mongodb.id
}

output "public_ip" {
  description = "MongoDB public IP"
  value       = aws_instance.mongodb.public_ip
}

output "private_ip" {
  description = "MongoDB private IP"
  value       = aws_instance.mongodb.private_ip
}

output "security_group_id" {
  description = "MongoDB security group ID"
  value       = aws_security_group.mongodb.id
}

output "iam_role_arn" {
  description = "MongoDB IAM role ARN"
  value       = aws_iam_role.mongodb.arn
}

output "ssh_key_name" {
  description = "SSH key pair name"
  value       = aws_key_pair.mongodb.key_name
}

output "ssh_private_key_ssm_parameter" {
  description = "SSM parameter name for SSH private key"
  value       = aws_ssm_parameter.mongodb_private_key.name
}

output "mongodb_connection_string" {
  description = "MongoDB connection string for application"
  value       = "mongodb://${var.mongodb_app_user}:${var.mongodb_app_pass}@${aws_instance.mongodb.private_ip}:27017/${var.mongodb_database}?authSource=${var.mongodb_database}"
  sensitive   = true
}
