# Goal contract

## Goal

{{GOAL}}

## Definition of done

- Repository context and relevant memory/instructions have been checked.
- Non-trivial work has a reference brief or documented skip reason.
- A spec and task DAG exist before implementation workers launch.
- Every worker has bounded scope, file/path claims, forbidden paths, acceptance criteria, and verification commands.
- Worker diffs are inspected against `{{BASE_REF}}`.
- Verification evidence is captured, or `NOT_APPLICABLE` has a concrete reason.
- Review passes with a matching diff hash before integration.
- Local integration is attempted only after review gates pass and main tracked changes are safe.
- Final report states what passed, failed, merged, or was skipped.

## Non-goals

{{NON_GOALS}}

## Constraints

{{CONSTRAINTS}}

## Forbidden actions

- No push, PR creation, deploy, publish, upload, or production external calls unless separately authorized.
- No overwriting unrelated user changes in the main worktree.
- No Codex worker edits to `~/.claude`, shell profiles, global git config, credentials, or unrelated user files.
- No secrets or environment variable dumps.

## Autonomy level

{{AUTONOMY_LEVEL}}

Commander should infer implementation details, ask only user-owned decisions, and stop only at terminal conditions.

## Required evidence

- `run.json`
- `goal-contract.md`
- `references/reference-brief.md` or skip reason
- `specs/spec.md`
- `tasks/task-dag.json`
- worker prompts/logs/state JSON
- diffs/stats/hashes
- verification output
- review decisions
- merge-gate output
- final report

## Stop conditions

- All tasks are reviewed and locally integrated.
- A genuinely user-owned decision is required.
- A safety boundary is hit.
- Max attempts/review cycles are exhausted.
- Verification cannot safely run and no substitute exists.
