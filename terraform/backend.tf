# Terraform Backend Configuration
# State is stored in S3 with DynamoDB locking for GitHub Actions

terraform {
  backend "s3" {
    bucket         = "wiz-exercise-tfstate-376129847397"
    key            = "wiz-exercise/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "wiz-exercise-tfstate-lock"
  }
}
