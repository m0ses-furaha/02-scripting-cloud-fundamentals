#!/bin/bash
# Kente Retail — First Cloud Footprint
# Recurring status/tag-compliance check against the resources
# provision_developer.sh created. Meant to be run on a schedule, e.g.:
#
#   Cron (every hour):
#     0 * * * * /path/to/scheduled_task.sh >> /var/log/kente-retail-compliance.log 2>&1
#
#   systemd timer (kente-retail-compliance.timer, OnCalendar=hourly) triggering
#   a kente-retail-compliance.service with ExecStart=/path/to/scheduled_task.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/config.sh"

REQUIRED_TAGS=(owner cost-center environment managed-by)

BUDGET_LIMIT_USD=20
BUDGET_WARN_PCT=80

check_tags() {
  local resource_label="$1"
  local tags_output="$2"
  local missing=()

  for key in "${REQUIRED_TAGS[@]}"; do
    if ! echo "${tags_output}" | awk -F'\t' '{print $1}' | grep -qx "${key}"; then
      missing+=("${key}")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    echo "[OK]   ${resource_label}: all required tags present."
  else
    echo "[WARN] ${resource_label}: missing tags: ${missing[*]}"
  fi
}

report_instance_status() {
  local instance_id
  instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --region "${REGION}" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || echo "None")

  if [ -z "${instance_id}" ] || [ "${instance_id}" == "None" ]; then
    echo "[WARN] Instance '${INSTANCE_NAME}' not found."
    return
  fi

  local state
  state=$(aws ec2 describe-instances \
    --instance-ids "${instance_id}" \
    --region "${REGION}" \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text)
  echo "[INFO] Instance ${instance_id} state: ${state}"

  local tags_output
  tags_output=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=${instance_id}" \
    --region "${REGION}" \
    --query "Tags[].[Key,Value]" \
    --output text)
  check_tags "EC2 instance ${instance_id}" "${tags_output}"
}

report_bucket_status() {
  if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
    echo "[WARN] Bucket '${BUCKET_NAME}' not found."
    return
  fi

  local tags_output
  tags_output=$(aws s3api get-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --query "TagSet[].[Key,Value]" \
    --output text 2>/dev/null || echo "")
  check_tags "S3 bucket ${BUCKET_NAME}" "${tags_output}"
}

check_budget() {
  local start_date end_date spend
  start_date=$(date -u +%Y-%m-01)
  end_date=$(date -u -d "+1 day" +%Y-%m-%d)

  spend=$(aws ce get-cost-and-usage \
    --time-period "Start=${start_date},End=${end_date}" \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    --filter "{\"Tags\":{\"Key\":\"cost-center\",\"Values\":[\"${COST_CENTER}\"]}}" \
    --query "ResultsByTime[0].Total.UnblendedCost.Amount" \
    --output text 2>/dev/null || echo "None")

  if [ -z "${spend}" ] || [ "${spend}" == "None" ]; then
    echo "[WARN] Budget check: could not retrieve cost data (Cost Explorer lags ~24h behind actual usage)."
    return
  fi


  local warn_limit is_over is_warn
  warn_limit=$(awk -v limit="${BUDGET_LIMIT_USD}" -v pct="${BUDGET_WARN_PCT}" 'BEGIN { printf "%.2f", limit * pct / 100 }')
  is_over=$(awk -v s="${spend}" -v l="${BUDGET_LIMIT_USD}" 'BEGIN { print (s > l) ? 1 : 0 }')
  is_warn=$(awk -v s="${spend}" -v w="${warn_limit}" 'BEGIN { print (s >= w) ? 1 : 0 }')

  if [ "${is_over}" -eq 1 ]; then
    echo "[CRIT] Budget check: month-to-date spend \$${spend} exceeds the \$${BUDGET_LIMIT_USD} budget."
  elif [ "${is_warn}" -eq 1 ]; then
    echo "[WARN] Budget check: month-to-date spend \$${spend} is at/above \$${warn_limit} (${BUDGET_WARN_PCT}% of \$${BUDGET_LIMIT_USD} budget)."
  else
    echo "[OK]   Budget check: month-to-date spend \$${spend} is within the \$${BUDGET_LIMIT_USD} budget."
  fi
}

main() {
  echo "=== Kente Retail compliance/status report — $(date -u +"%Y-%m-%dT%H:%M:%SZ") ==="
  report_instance_status
  report_bucket_status
  check_budget
  echo "=== End report ==="
}

main "$@"
