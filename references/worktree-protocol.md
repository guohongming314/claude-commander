# Worktree protocol

## Default paths

Run state:

```text
~/.claude/commander/runs/<run-id>/
```

Default user-global worktrees:

```text
~/.claude/commander/worktrees/<repo-slug>/<run-id>/<task-id>/
```

Project-local worktrees are explicit opt-in only, via `launch-worker.sh --worktree-root`:

```text
<repo>/.claude/commander/worktrees/<run-id>/<task-id>/
```

## Branch names

```text
commander/<run-id>/<task-id>
commander/<run-id>/integration
```

## Creation

```bash
git worktree add -b "commander/<run-id>/<task-id>" "<worktree-path>" "<base-ref>"
```

## Verification before worker launch

- path exists;
- canonical path is under a configured Commander worktree root;
- path is not the broad root itself;
- path is not a symlink escape;
- git top-level equals canonical worktree path;
- branch name matches expected branch;
- base ref is recorded;
- prompt and log paths are under the run directory.

## Validation before cleanup or merge

Before any destructive cleanup or merge action, Commander must validate:

- `run.json` and worker state exist;
- the worker worktree path canonicalizes under either:
  - `~/.claude/commander/worktrees/...`, or
  - explicit project-local `<repo>/.claude/commander/worktrees/...`;
- the path is not the broad worktree root;
- `git -C "$WORKTREE" rev-parse --show-toplevel` equals the canonical worktree path;
- the current branch equals `commander/<run-id>/<task-id>`.

If validation fails, do not reset, clean, remove, commit, or merge that worktree.

## Cleanup

Keep worktrees by default for audit. Cleanup must:

- operate only on validated Commander-owned worktree roots;
- refuse dirty worktrees unless `--force` is explicitly passed;
- never delete arbitrary paths;
- report failures rather than silently skipping unsafe state;
- record cleanup in the run report.
