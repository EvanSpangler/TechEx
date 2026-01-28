# Wazuh Module - Security monitoring and SIEM for Wiz exercise
# Deploys Wazuh Manager using Docker Compose

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Wazuh Manager
resource "aws_security_group" "wazuh" {
  name        = "${var.environment}-wazuh-sg"
  description = "Security group for Wazuh Manager"
  vpc_id      = var.vpc_id

  # Wazuh Dashboard (HTTPS)
  ingress {
    description = "Wazuh Dashboard"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # Wazuh Agent enrollment
  ingress {
    description = "Wazuh Agent enrollment"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Wazuh Agent communication
  ingress {
    description = "Wazuh Agent communication"
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH for management
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # Wazuh API
  ingress {
    description = "Wazuh API"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-wazuh-sg"
  })
}

# IAM Role for Wazuh
resource "aws_iam_role" "wazuh" {
  name = "${var.environment}-wazuh-role"

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

resource "aws_iam_role_policy" "wazuh" {
  name = "${var.environment}-wazuh-policy"
  role = aws_iam_role.wazuh.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.environment}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "wazuh" {
  name = "${var.environment}-wazuh-profile"
  role = aws_iam_role.wazuh.name
}

# SSH Key Pair
resource "tls_private_key" "wazuh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "wazuh" {
  key_name   = "${var.environment}-wazuh-key"
  public_key = tls_private_key.wazuh.public_key_openssh

  tags = var.tags
}

resource "aws_ssm_parameter" "wazuh_private_key" {
  name        = "/${var.environment}/wazuh/ssh-private-key"
  description = "SSH private key for Wazuh Manager"
  type        = "SecureString"
  value       = tls_private_key.wazuh.private_key_pem

  tags = var.tags
}

# Wazuh Manager EC2 Instance
resource "aws_instance" "wazuh" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.wazuh.key_name
  vpc_security_group_ids      = [aws_security_group.wazuh.id]
  subnet_id                   = var.public_subnet_id
  iam_instance_profile        = aws_iam_instance_profile.wazuh.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/wazuh-userdata.sh.tpl", {
    environment        = var.environment
    wazuh_admin_pass   = var.wazuh_admin_password
    wazuh_api_user     = var.wazuh_api_user
    wazuh_api_pass     = var.wazuh_api_password
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-wazuh-manager"
  })
}

# Store Wazuh credentials in SSM
resource "aws_ssm_parameter" "wazuh_admin_password" {
  name        = "/${var.environment}/wazuh/admin-password"
  description = "Wazuh Dashboard admin password"
  type        = "SecureString"
  value       = var.wazuh_admin_password

  tags = var.tags
}
