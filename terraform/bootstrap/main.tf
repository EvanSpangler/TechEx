# Bootstrap - Creates S3 bucket and DynamoDB table for Terraform state
# Run this ONCE locally before using GitHub Actions

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "wiz-exercise-tfstate-${local.account_id}"
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  tags = {
    Name    = "Terraform State"
    Project = "wiz-exercise"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "wiz-exercise-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "Terraform State Lock"
    Project = "wiz-exercise"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.tfstate_lock.name
}

output "backend_config" {
  value = <<-EOT
    Update terraform/backend.tf with:

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.tfstate.bucket}"
        key            = "wiz-exercise/terraform.tfstate"
        region         = "us-east-1"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.tfstate_lock.name}"
      }
    }
  EOT
}
