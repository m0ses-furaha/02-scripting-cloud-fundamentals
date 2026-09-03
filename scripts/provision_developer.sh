#!/bin/bash


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

create_security_group() {
  local sg_id
  sg_id=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
    --region "${REGION}" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

  if [ -n "${sg_id}" ] && [ "${sg_id}" != "None" ]; then
    echo "Security group '${SECURITY_GROUP_NAME}' already exists (${sg_id}). Skipping creation." >&2
    echo "${sg_id}"
    return
  fi

  echo "Creating security group '${SECURITY_GROUP_NAME}'..." >&2
  sg_id=$(aws ec2 create-security-group \
    --group-name "${SECURITY_GROUP_NAME}" \
    --description "Kente Retail developer sandbox SG - SSH (22)" \
    --region "${REGION}" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=owner,Value=${OWNER}},{Key=cost-center,Value=${COST_CENTER}},{Key=environment,Value=${ENVIRONMENT}},{Key=managed-by,Value=${MANAGED_BY}}]" \
    --query "GroupId" \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id "${sg_id}" \
    --protocol tcp --port 22 --cidr "0.0.0.0/0" \
    --region "${REGION}" >/dev/null

  echo "${sg_id}"
}

create_s3_bucket() {
  if aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
    echo "Bucket '${BUCKET_NAME}' already exists. Skipping creation." >&2
    return
  fi

  echo "Creating S3 bucket '${BUCKET_NAME}'..." >&2
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null

  aws s3api put-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --tagging "TagSet=[{Key=owner,Value=${OWNER}},{Key=cost-center,Value=${COST_CENTER}},{Key=environment,Value=${ENVIRONMENT}},{Key=managed-by,Value=${MANAGED_BY}}]"
}

create_ec2_instance() {
  local sg_id="$1"
  local instance_id
  instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=pending,running,stopped" \
    --region "${REGION}" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || echo "None")

  if [ -n "${instance_id}" ] && [ "${instance_id}" != "None" ]; then
    echo "Instance '${INSTANCE_NAME}' already exists (${instance_id}). Skipping creation." >&2
    echo "${instance_id}"
    return
  fi

  echo "Launching EC2 instance '${INSTANCE_NAME}'..." >&2
  instance_id=$(aws ec2 run-instances \
    --image-id "${AMI_ID}" \
    --instance-type "${INSTANCE_TYPE}" \
    --key-name "${KEY_NAME}" \
    --security-group-ids "${sg_id}" \
    --region "${REGION}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}},{Key=owner,Value=${OWNER}},{Key=cost-center,Value=${COST_CENTER}},{Key=environment,Value=${ENVIRONMENT}},{Key=managed-by,Value=${MANAGED_BY}}]" \
    --query "Instances[0].InstanceId" \
    --output text)

  echo "${instance_id}"
}

create_iam_resources() {
  local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${DEVELOPER_POLICY}"
  local rendered_policy
  rendered_policy="$(mktemp)"

  sed \
    -e "s|\${REGION}|${REGION}|g" \
    -e "s|\${ACCOUNT_ID}|${ACCOUNT_ID}|g" \
    -e "s|\${BUCKET_NAME}|${BUCKET_NAME}|g" \
    -e "s|\${STUDENT_PREFIX}|${STUDENT_PREFIX}|g" \
    "${SCRIPT_DIR}/../policies/developer-policy.json" > "${rendered_policy}"

  if aws iam get-policy --policy-arn "${policy_arn}" >/dev/null 2>&1; then
    echo "Policy '${DEVELOPER_POLICY}' already exists. Skipping creation." >&2
  else
    echo "Creating IAM policy '${DEVELOPER_POLICY}'..." >&2
    aws iam create-policy \
      --policy-name "${DEVELOPER_POLICY}" \
      --policy-document "$(cat "${rendered_policy}")" \
      --tags "Key=owner,Value=${OWNER}" "Key=cost-center,Value=${COST_CENTER}" "Key=environment,Value=${ENVIRONMENT}" "Key=managed-by,Value=${MANAGED_BY}" \
      >/dev/null
  fi

  rm -f "${rendered_policy}"

  if aws iam get-group --group-name "${DEVELOPER_GROUP}" >/dev/null 2>&1; then
    echo "Group '${DEVELOPER_GROUP}' already exists. Skipping creation." >&2
  else
    echo "Creating IAM group '${DEVELOPER_GROUP}'..." >&2
    aws iam create-group --group-name "${DEVELOPER_GROUP}" >/dev/null
  fi

  aws iam attach-group-policy \
    --group-name "${DEVELOPER_GROUP}" \
    --policy-arn "${policy_arn}"

  if aws iam get-user --user-name "${DEVELOPER_USER}" >/dev/null 2>&1; then
    echo "User '${DEVELOPER_USER}' already exists. Skipping creation." >&2
  else
    echo "Creating IAM user '${DEVELOPER_USER}'..." >&2
    aws iam create-user \
      --user-name "${DEVELOPER_USER}" \
      --tags "Key=owner,Value=${OWNER}" "Key=cost-center,Value=${COST_CENTER}" "Key=environment,Value=${ENVIRONMENT}" "Key=managed-by,Value=${MANAGED_BY}" \
      >/dev/null
  fi

  aws iam add-user-to-group \
    --group-name "${DEVELOPER_GROUP}" \
    --user-name "${DEVELOPER_USER}"
}

main() {
  echo "Using region: ${REGION}"

  local sg_id
  sg_id=$(create_security_group)

  create_s3_bucket

  local instance_id
  instance_id=$(create_ec2_instance "${sg_id}")

  create_iam_resources

  echo "-----------------------------------"
  echo "Security group: ${sg_id}"
  echo "S3 bucket:      ${BUCKET_NAME}"
  echo "Instance ID:    ${instance_id}"
  echo "-----------------------------------"
}

main "$@"
