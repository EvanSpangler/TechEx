# Red Team Module - Attack simulation instance for Wiz exercise
# Used for demonstrating attack chains and security tool detections

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

# Security Group for Red Team instance
resource "aws_security_group" "redteam" {
  name        = "${var.environment}-redteam-sg"
  description = "Security group for Red Team instance"
  vpc_id      = var.vpc_id

  # SSH - restricted to allowed CIDRs
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-redteam-sg"
  })
}

# IAM Role for Red Team (minimal permissions)
resource "aws_iam_role" "redteam" {
  name = "${var.environment}-redteam-role"

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

resource "aws_iam_role_policy" "redteam" {
  name = "${var.environment}-redteam-policy"
  role = aws_iam_role.redteam.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "redteam" {
  name = "${var.environment}-redteam-profile"
  role = aws_iam_role.redteam.name
}

# SSH Key Pair
resource "tls_private_key" "redteam" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "redteam" {
  key_name   = "${var.environment}-redteam-key"
  public_key = tls_private_key.redteam.public_key_openssh

  tags = var.tags
}

resource "aws_ssm_parameter" "redteam_private_key" {
  name        = "/${var.environment}/redteam/ssh-private-key"
  description = "SSH private key for Red Team instance"
  type        = "SecureString"
  value       = tls_private_key.redteam.private_key_pem

  tags = var.tags
}

# Red Team EC2 Instance
resource "aws_instance" "redteam" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.redteam.key_name
  vpc_security_group_ids      = [aws_security_group.redteam.id]
  subnet_id                   = var.public_subnet_id
  iam_instance_profile        = aws_iam_instance_profile.redteam.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/redteam-userdata.sh.tpl", {
    environment   = var.environment
    mongodb_ip    = var.mongodb_private_ip
    eks_cluster   = var.eks_cluster_name
    backup_bucket = var.backup_bucket_name
    aws_region    = var.aws_region
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-redteam"
  })
}
