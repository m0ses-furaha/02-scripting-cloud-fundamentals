#!/bin/bash

# Kente Retail — First Cloud Footprint
# Shared configuration

set -euo pipefail

# AWS
REGION="eu-west-1"

# Provisional learner/resource prefix
STUDENT_PREFIX="mf01"

# Project
PROJECT_NAME="kente-retail"

# IAM
DEVELOPER_USER="${STUDENT_PREFIX}-developer"
DEVELOPER_GROUP="${STUDENT_PREFIX}-developers"
DEVELOPER_POLICY="${STUDENT_PREFIX}-developer-policy"

# EC2
INSTANCE_NAME="${STUDENT_PREFIX}-app-server"
INSTANCE_TYPE="t3.micro"
AMI_ID="resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
KEY_NAME="kental-key-pair"

# Security Group
SECURITY_GROUP_NAME="${STUDENT_PREFIX}-sg"

# S3
BUCKET_PREFIX="${STUDENT_PREFIX}-${PROJECT_NAME}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET_NAME="${BUCKET_PREFIX}-${ACCOUNT_ID}"

# Tags
OWNER="${STUDENT_PREFIX}"
COST_CENTER="${STUDENT_PREFIX}"
ENVIRONMENT="dev"
MANAGED_BY="bash"