# Commander spec

## Goal

{{GOAL}}

## Context summary

{{CONTEXT_SUMMARY}}

## Reference brief summary

{{REFERENCE_SUMMARY}}

## Proposed approach

{{APPROACH}}

## Task DAG summary

{{TASK_DAG_SUMMARY}}

## File/path claim strategy

- `owned`: task may edit.
- `shared`: task may edit only with coordination and review.
- `read_only`: task may inspect but not modify.
- `forbidden`: task must not touch.

{{FILE_CLAIMS_SUMMARY}}

## Verification plan

{{VERIFICATION_PLAN}}

## Review rubric

- Correctness bugs.
- Scope drift or file-claim violations.
- Missing or insufficient verification.
- Safety boundary violations.
- Simplicity and maintainability.
- Goal contract compliance.
- Reference/spec decision compliance.

Findings must be classified as `blocking`, `important`, `suggestion`, or `nit`.

## Retry/revision policy

{{RETRY_POLICY}}

## Rollback/integration plan

- Keep worker worktrees and logs for audit.
- Commit worker diffs only through merge gate.
- Merge only into local `commander/{{RUN_ID}}/integration` unless separately authorized.
- If merge conflicts or main tracked changes block integration, stop and report the blocker.
