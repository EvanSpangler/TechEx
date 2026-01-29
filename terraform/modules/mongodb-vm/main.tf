# MongoDB VM Module - Intentionally vulnerable configuration for Wiz exercise
# VULNERABILITIES BY DESIGN:
# - Ubuntu 20.04 LTS (1+ year outdated)
# - MongoDB 4.4 (1+ year outdated)
# - SSH exposed to 0.0.0.0/0
# - Overly permissive IAM role (ec2:*)

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group - INTENTIONALLY INSECURE: SSH open to world
resource "aws_security_group" "mongodb" {
  name        = "${var.environment}-mongodb-sg"
  description = "Security group for MongoDB VM - INTENTIONALLY INSECURE"
  vpc_id      = var.vpc_id

  # SSH - VULNERABILITY: Open to the world
  ingress {
    description = "SSH from anywhere - INTENTIONALLY INSECURE"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB - Only from private subnets (K8s network)
  ingress {
    description = "MongoDB from private subnets only"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-mongodb-sg"
  })
}

# IAM Role - INTENTIONALLY OVERPERMISSIVE
resource "aws_iam_role" "mongodb" {
  name = "${var.environment}-mongodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# VULNERABILITY: Overly permissive IAM policy
resource "aws_iam_role_policy" "mongodb_overpermissive" {
  name = "${var.environment}-mongodb-overpermissive"
  role = aws_iam_role.mongodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OverlyPermissiveEC2"
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        Sid    = "S3BackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.backup_bucket_arn,
          "${var.backup_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "${var.environment}-mongodb-profile"
  role = aws_iam_role.mongodb.name
}

# SSH Key Pair
resource "tls_private_key" "mongodb" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "mongodb" {
  key_name   = "${var.environment}-mongodb-key"
  public_key = tls_private_key.mongodb.public_key_openssh

  tags = var.tags
}

# Store private key in SSM Parameter Store (for demo access)
resource "aws_ssm_parameter" "mongodb_private_key" {
  name        = "/${var.environment}/mongodb/ssh-private-key"
  description = "SSH private key for MongoDB VM"
  type        = "SecureString"
  value       = tls_private_key.mongodb.private_key_pem

  tags = var.tags
}

# MongoDB EC2 Instance
resource "aws_instance" "mongodb" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.mongodb.key_name
  vpc_security_group_ids      = [aws_security_group.mongodb.id]
  subnet_id                   = var.public_subnet_id
  iam_instance_profile        = aws_iam_instance_profile.mongodb.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/mongodb-userdata.sh.tpl", {
    mongodb_admin_user    = var.mongodb_admin_user
    mongodb_admin_pass    = var.mongodb_admin_pass
    mongodb_app_user      = var.mongodb_app_user
    mongodb_app_pass      = var.mongodb_app_pass
    mongodb_database      = var.mongodb_database
    backup_bucket         = var.backup_bucket_name
    backup_encryption_key = var.backup_encryption_key
    environment           = var.environment
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" # VULNERABILITY: IMDSv1 enabled
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-mongodb"
  })
}
