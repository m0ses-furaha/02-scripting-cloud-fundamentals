# Assumptions Log

Keep this updated as you work, not written retroactively the night before your
walkthrough — the instructor can tell the difference.

## Developer persona — access needs beyond what the brief states outright

Since the official `PERSONA_BRIEF.md` wasn't in the starter repo, I authored a
working-assumption persona (see `docs/PERSONA_BRIEF.md`) and derived
`policies/developer-policy.json` from its stated responsibilities/restrictions.
Justification per statement:

- `DescribeEc2ForVisibility` (ec2:Describe*, Resource `*`) — read-only visibility
  the brief asks for ("view relevant resource information"). Resource must be `*`:
  AWS's `Describe*` EC2 actions don't support resource-level/tag-conditioned
  permissions, so this can't be scoped tighter — noted as a real IAM limitation,
  not an oversight.
- `ManageOwnEc2Instance` (ec2:Start/Stop/RebootInstances, scoped to
  `ec2:ResourceTag/owner = ${STUDENT_PREFIX}`) — covers "start, stop, and restart
  development workloads" while the tag condition prevents touching any instance
  not tagged as theirs.
- `ReadWriteOwnS3Bucket` (s3:GetObject/PutObject/ListBucket, scoped to
  `${BUCKET_NAME}` only) — covers "access application artifacts stored in S3,"
  restricted to the one bucket this script provisions, not `arn:aws:s3:::*`.
- `ReadOwnApplicationLogs` (logs:Describe/Get/FilterLogEvents, scoped to log
  group prefix `/kente-retail/${STUDENT_PREFIX}*`) — covers "read application logs
  for troubleshooting" without granting access to other log groups in the account.

Deliberately NOT granted (per the persona's "Assumed Restrictions"): no `iam:*`,
no billing/cost-explorer actions, no `ec2:TerminateInstances`, no wildcard S3
bucket access, no account-settings actions.

## Clarifying questions you'd ask the CTO in a real engagement

<!-- Things you guessed at instead of asking, and what you'd confirm first if this
     were a real client engagement. -->

- Does the developer persona need write access to CloudWatch Logs (e.g. to ship
  custom app logs) or read-only, as assumed here?
- Should the developer be able to terminate their own instance, or only
  start/stop/reboot (assumed the more conservative option)?
- Is there a real log group naming convention in use, or is
  `/kente-retail/${STUDENT_PREFIX}*` (assumed here) fine to keep?

## Other requirement gaps you filled in yourself

<!-- Anything the brief left ambiguous or unspecified that you had to decide on your
     own (e.g. instance size, region, naming convention, tag values). -->
