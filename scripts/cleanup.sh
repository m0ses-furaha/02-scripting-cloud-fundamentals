#!/bin/bash
# Kente Retail — First Cloud Footprint
# Tears down everything provision_developer.sh created: IAM user/group/policy,
# EC2 instance, security group, S3 bucket. Idempotent: safe to re-run, and
# safe to run against a partially-provisioned or already-torn-down environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

delete_iam_resources() {
  local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${DEVELOPER_POLICY}"

  if aws iam get-user --user-name "${DEVELOPER_USER}" >/dev/null 2>&1; then
    aws iam remove-user-from-group \
      --user-name "${DEVELOPER_USER}" \
      --group-name "${DEVELOPER_GROUP}" 2>/dev/null || true
    echo "Deleting IAM user '${DEVELOPER_USER}'..." >&2
    aws iam delete-user --user-name "${DEVELOPER_USER}"
  else
    echo "User '${DEVELOPER_USER}' not found. Skipping." >&2
  fi

  if aws iam get-group --group-name "${DEVELOPER_GROUP}" >/dev/null 2>&1; then
    aws iam detach-group-policy \
      --group-name "${DEVELOPER_GROUP}" \
      --policy-arn "${policy_arn}" 2>/dev/null || true
    echo "Deleting IAM group '${DEVELOPER_GROUP}'..." >&2
    aws iam delete-group --group-name "${DEVELOPER_GROUP}"
  else
    echo "Group '${DEVELOPER_GROUP}' not found. Skipping." >&2
  fi

  if aws iam get-policy --policy-arn "${policy_arn}" >/dev/null 2>&1; then
    echo "Deleting IAM policy '${DEVELOPER_POLICY}'..." >&2
    aws iam delete-policy --policy-arn "${policy_arn}"
  else
    echo "Policy '${DEVELOPER_POLICY}' not found. Skipping." >&2
  fi
}

terminate_ec2_instance() {
  local instance_id
  instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --region "${REGION}" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || echo "None")

  if [ -z "${instance_id}" ] || [ "${instance_id}" == "None" ]; then
    echo "Instance '${INSTANCE_NAME}' not found. Skipping." >&2
    return
  fi

  echo "Terminating instance '${instance_id}'..." >&2
  aws ec2 terminate-instances --instance-ids "${instance_id}" --region "${REGION}" >/dev/null
  echo "Waiting for instance to terminate..." >&2
  aws ec2 wait instance-terminated --instance-ids "${instance_id}" --region "${REGION}"
}

delete_security_group() {
  local sg_id
  sg_id=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
    --region "${REGION}" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

  if [ -z "${sg_id}" ] || [ "${sg_id}" == "None" ]; then
    echo "Security group '${SECURITY_GROUP_NAME}' not found. Skipping." >&2
    return
  fi

  echo "Deleting security group '${sg_id}'..." >&2
  aws ec2 delete-security-group --group-id "${sg_id}" --region "${REGION}"
}

delete_s3_bucket() {
  if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
    echo "Bucket '${BUCKET_NAME}' not found. Skipping." >&2
    return
  fi

  echo "Emptying bucket '${BUCKET_NAME}'..." >&2
  aws s3 rm "s3://${BUCKET_NAME}" --recursive --region "${REGION}" >/dev/null

  echo "Deleting bucket '${BUCKET_NAME}'..." >&2
  aws s3api delete-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
}

main() {
  echo "Using region: ${REGION}"

  delete_iam_resources
  terminate_ec2_instance
  delete_security_group
  delete_s3_bucket

  echo "-----------------------------------"
  echo "Cleanup complete. Verify with:"
  echo "  aws ec2 describe-instances --filters Name=tag:Name,Values=${INSTANCE_NAME} --region ${REGION}"
  echo "  aws ec2 describe-security-groups --filters Name=group-name,Values=${SECURITY_GROUP_NAME} --region ${REGION}"
  echo "  aws s3api head-bucket --bucket ${BUCKET_NAME} --region ${REGION}"
  echo "  aws iam get-user --user-name ${DEVELOPER_USER}"
  echo "-----------------------------------"
}

main "$@"
