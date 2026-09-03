# AI Log

AI use is permitted and must be logged — it is never penalized on its own. You are
assessed on whether you can defend, verify, and correct what an AI tool produced.
Thoughtful rejection of AI output scores higher than blind acceptance.

Add one entry per session you use an AI tool, even briefly.

## Entry template (copy for each session)

- **Date:**
- **Tool:**
- **Prompt(s) used:**
- **What was accepted:**
- **What was rejected or changed, and why:**

## Session — 2026-09-03

- **Date:** 2026-09-03
- **Tool:** Claude Code (Sonnet 5)
- **Prompt(s) used:** Requested completion of the EC2 provisioning CLI script from supplied configuration values and a user-data payload; requested a budget-monitoring capability for the scheduled compliance task; requested clarification on AWS budget behavior, IAM scoping, and the assignment's incident and value-add requirements; requested a set of AWS CLI sequences for personally rehearsing incident detection prior to the graded walkthrough.
- **What was accepted:**
  - Completion of `scripts/cli_script.sh`: argument parsing, the `run-instances` call, an instance-running wait, and final connection-details output, built from the supplied AMI, instance type, key name, security group ID, instance name, and user-data content.
  - Addition of a `check_budget()` function to `scripts/scheduled_task.sh`, querying Cost Explorer month-to-date spend against the $20 exercise budget with an 80% warning threshold, and a corresponding `ce:GetCostAndUsage` permission added to `policies/developer-policy.json`.
  - A reference set of AWS CLI commands for rehearsing detection of tag drift, instance state changes, security-group and IAM policy changes ahead of the Day-2 incident walkthrough.
- **What was rejected or changed, and why:**
  - Did not accept an AI-suggested replacement for the security group ID supplied in `cli_script.sh`, despite it failing validation against the target VPC; the value was left as originally provided pending manual verification, and a follow-up prompt proposing resolution options was declined so the decision remains mine.
  - Declined to have the rehearsal command set committed to the repository as a script file, since it supports personal preparation rather than being a graded deliverable.
  - Identified that the `check_budget()` feature was implemented ahead of the assignment's required Value-Add Proposal process, which calls for pitching two candidate operational conveniences and building only the one the instructor approves. It is treated as a candidate pending that approval, not a finished feature.
