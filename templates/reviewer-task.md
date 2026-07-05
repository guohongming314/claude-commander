# Reviewer task

You are a read-only reviewer. Review the worker diff for task `{{TASK_ID}}`.

Do not modify files.

## Inputs

Original task:

{{TASK_GOAL}}

Acceptance criteria:

{{ACCEPTANCE_CRITERIA}}

Diff summary / diff path:

{{DIFF_INPUT}}

Review snapshot metadata:

{{SNAPSHOT_INPUT}}

Verification output:

{{VERIFICATION_OUTPUT}}

## Review checklist

1. Correctness bugs
2. Scope drift, file-claim violations, or unrelated changes
3. Missing or broken tests/checks
4. Safety boundary violations
5. Simplicity and maintainability
6. Merge readiness
7. Whether verification evidence is sufficient
8. Whether the diff satisfies the goal contract and reference/spec decisions

Classify findings by severity: `blocking`, `important`, `suggestion`, or `nit`. Only `blocking` findings should force `FAIL_REVISE` unless safety requires `FAIL_ABORT`.

## Output format

Return this structure exactly enough for the merge gate to parse these top-level fields:

```yaml
task_id: {{TASK_ID}}
decision: PASS | PASS_WITH_NOTES | FAIL_REVISE | FAIL_ABORT
reviewed_diff_sha256: "<copy from snapshot>"
reviewed_worker_head: "<copy from snapshot>"
verification_status: PASS | NOT_APPLICABLE | FAIL | MISSING
verification_evidence:
  - command: "<command run, or NOT_APPLICABLE>"
    exit_code: 0
    summary: "<observed result, or why verification is not applicable>"
summary: "..."
blocking_findings:
  - file: "path"
    issue: "..."
    evidence: "..."
    suggested_fix: "..."
nonblocking_findings:
  - file: "path"
    issue: "..."
verification_notes:
  commands_run:
    - command: "..."
      exit_code: 0
      summary: "..."
merge_recommendation: merge | revise | abort
```

A review becomes stale if the worker diff changes after this snapshot. If you cannot verify the work, use `verification_status: MISSING` or `FAIL`, not PASS.
