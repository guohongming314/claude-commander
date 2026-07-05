# Revision task

You are revising task `{{TASK_ID}}` after review failure.

## Original task

{{TASK_GOAL}}

## Reference/spec constraints

{{REFERENCE_AND_SPEC_CONSTRAINTS}}

## File/path claims

{{FILE_CLAIMS}}

## Reviewer blocking findings

{{BLOCKING_FINDINGS}}

## Verification failures

{{VERIFICATION_FAILURES}}

## Instructions

- Fix only the blocking issues.
- Preserve correct existing work.
- Do not broaden scope.
- Stay inside the assigned worktree.
- Do not push, deploy, publish, or edit global config.
- Re-run verification.
- Record verification evidence in the reviewer-compatible format (`verification_status` plus command evidence or NOT_APPLICABLE reason).

## Completion output

Return:

1. Fixes made
2. Files changed
3. Verification rerun and results
4. Whether ready for review
