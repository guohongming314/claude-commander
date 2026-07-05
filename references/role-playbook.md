# Role playbook

## Commander

Owns the whole run. Splits the goal, assigns workers, monitors, reviews, integrates, and reports. Uses real diffs and verification, not worker claims.

## Implementer worker

Builds one bounded feature/fix in one worktree. Avoids global side effects. Produces small, reviewable diff.

## Research worker

Read-only exploration in a worktree or main repo. Produces findings, candidate files, risks, and suggested implementation tasks. Should not modify code.

## Asset/data worker

Works on assets, JSON, CSV, configuration, or generated data. Must preserve source/licensing notes and avoid deleting existing assets without approval.

## Test worker

Adds or improves tests/checks. May fail the build intentionally only if documenting a real bug before implementation fixes it.

## Reviewer

Read-only. Checks correctness, scope, tests, security boundaries, maintainability, and merge readiness. Returns `PASS`, `PASS_WITH_NOTES`, `FAIL_REVISE`, or `FAIL_ABORT`.

## Conflict worker

Optional. Handles merge conflicts in an integration worktree only after Commander provides exact branches and conflict scope. Must not broaden feature scope.
