# Kente Retail — First Cloud Footprint

Starter repo for the "First Cloud Footprint" lab. This is the repo you'll build your
submission in — commit to it as you go, not just at the end (commit cadence and
messages are part of Process Evidence in the rubric).

## What you're given

- This README and the `docs/` templates below.
- A `PERSONA_BRIEF.md` will be added to your clone/remote before the lab opens — it
  describes your assigned developer persona and your application-config requirements
  list. There is no starter YAML/JSON template: you author both files yourself from
  that requirements list.
- See `aws-sandbox-account-access.md` (one level up, alongside this repo) for how to
  get AWS sandbox credentials.

## What you build (deliverables checklist)

Track your own progress — none of this is provided as a template:

- [ ] Provisioning script — idempotent Bash: functions, error handling, input
      validation. Provisions an EC2 instance, a security group, and an S3 bucket.
      Re-running it must not error and must not create duplicates.
- [ ] IAM policy definition — least-privilege user/group/policy for your assigned
      persona. Every permission needs a one-line justification. No unjustified
      wildcard actions or resources.
- [ ] Application configuration — YAML **and** JSON, hand-authored from your
      `PERSONA_BRIEF.md` requirements list, matching content between the two formats.
      No plaintext secrets — use environment-variable placeholders. Validate the JSON
      with `jq`.
- [ ] Resource-tagging taxonomy — at minimum `cost-center`, `environment`, `owner` —
      applied to every resource your script creates, with a short written
      justification for the taxonomy you chose.
- [ ] Scheduled automation — a cron job or systemd timer running a recurring task
      against your provisioned resources (e.g. a cost/tag-compliance check or a
      status report).
- [ ] Cleanup script — tears everything down, and you can prove (console check or
      CLI query) that zero resources remain.
- [ ] `docs/EXECUTIVE_SUMMARY.md` — one page.
- [ ] `docs/ASSUMPTIONS_LOG.md` — filled in as you go, not written retroactively.
- [ ] `docs/AI_LOG.md` — every session you use an AI tool, even briefly.
- [ ] `docs/INCIDENT_REPORT.md` — after the Day-2 incident during your walkthrough.

## Budget

Target spend for the whole exercise: **under $20**. There's a hard teardown deadline —
your instructor will confirm the exact date/time for your cohort. Cost Explorer data
lags about 24 hours behind actual usage, so don't wait until the deadline to check your
running total.

## A note on the Day-2 incident

Something in your environment will change without warning during your defense
walkthrough. That's expected — see `docs/INCIDENT_REPORT.md` for the template you'll
fill in once it happens.

## Architecture

```
config/config.sh                    single source of truth: names, region, tags
        │
        ├── scripts/provision_developer.sh   creates SG, S3 bucket, EC2 instance, IAM user/group/policy
        ├── scripts/scheduled_task.sh        recurring drift, tag-compliance, and budget report
        ├── scripts/cleanup.sh               tears down everything provision_developer.sh created
        └── policies/developer-policy.json   least-privilege policy attached to the IAM group

config/developer.yaml, developer.json   hand-authored app config, same content in both formats
scripts/cli_script.sh                   standalone EC2 launch path with an embedded user-data bootstrap
```

`provision_developer.sh`, `scheduled_task.sh`, and `cleanup.sh` all source the same
`config/config.sh`, so a resource name, region, or tag value only has to change in one
place to stay consistent across provisioning, monitoring, and teardown.

## Best practices followed

- **Idempotency** — every create step in `provision_developer.sh` checks for an
  existing resource (by name or tag) before creating one, so re-running the script
  never errors and never duplicates a resource. `cleanup.sh` mirrors this: every delete
  step checks existence first and skips cleanly if the resource is already gone.
- **Least privilege, justified** — `policies/developer-policy.json` scopes each
  statement to the specific actions the persona needs, with resource ARNs and
  `ec2:ResourceTag` conditions restricting access to the student's own resources
  wherever the AWS API allows it. The one exception (`ce:GetCostAndUsage`, needed for
  the budget check) is called out on its own because Cost Explorer has no
  resource-level permissions to scope it with.
- **Consistent tagging for cost allocation** — `owner`, `cost-center`, `environment`,
  and `managed-by` are applied to every resource `provision_developer.sh` creates, and
  `scheduled_task.sh` actively checks for their presence rather than assuming they
  stick.
- **No plaintext secrets** — `developer.yaml` and `developer.json` reference
  `${AWS_ACCESS_KEY_ID}` / `${AWS_SECRET_ACCESS_KEY}` as environment-variable
  placeholders rather than literal credentials.
- **Fail-soft monitoring** — `scheduled_task.sh` degrades to a `[WARN]` log line
  instead of crashing under `set -euo pipefail` when a resource or cost figure isn't
  available yet (e.g. Cost Explorer's ~24h reporting lag), so a transient gap in data
  doesn't take down the whole compliance run.
- **Proactive budget visibility** — the AWS Budget alarm mentioned in
  `aws-sandbox-account-access.md` only notifies the instructor. `scheduled_task.sh`
  adds a second, student-facing check: month-to-date Cost Explorer spend against the
  $20 budget with an 80% warning threshold, logged on every scheduled run instead of
  relying on a single end-of-exercise figure.
