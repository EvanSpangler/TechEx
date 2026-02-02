#!/bin/bash
# scripts/import_logs.sh
# Imports existing CloudWatch Log Groups into Terraform state to prevent "ResourceAlreadyExists" errors.

set -e

REGION=${1:-"us-east-1"}
TF_DIR=${2:-"terraform"}

echo "Checking for existing CloudWatch Log Groups in $REGION..."

# Function to import if exists and not in state
import_if_exists() {
  local LOG_GROUP=$1
  local RESOURCE_ADDR=$2

  echo "Processing $LOG_GROUP..."

  # Check if exists in AWS (exact match)
  if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" --query 'logGroups[?logGroupName==`'"$LOG_GROUP"'`].logGroupName' --output text | grep -q "$LOG_GROUP"; then
    echo "  -> Found in AWS."
    
    # Check if in Terraform state
    if cd "$TF_DIR" && terraform state list | grep -Fq "$RESOURCE_ADDR"; then
      echo "  -> Already in Terraform state. Skipping."
    else
      echo "  -> Not in state. Importing..."
      # Use || true to prevent script failure if import fails (e.g. race condition)
      (cd "$TF_DIR" && terraform import -var-file="environments/demo.tfvars" "$RESOURCE_ADDR" "$LOG_GROUP") || echo "  -> Import failed."
    fi
  else
    echo "  -> Not found in AWS. Skipping."
  fi
}

import_if_exists "/aws/eks/wiz-exercise-eks/cluster" "module.eks.aws_cloudwatch_log_group.eks"
import_if_exists "/aws/vpc-flow-logs/wiz-exercise" "module.vpc.aws_cloudwatch_log_group.flow_logs[0]"

echo "Log group check complete."
