# Troubleshooting

## `tmux` missing

Use background process + log files. Ask before installing `tmux`.

## `codex-unsafe` parses arguments strangely

The wrapper appends `--dangerously-bypass-approvals-and-sandbox` after all user arguments. Prefer no prompt positional argument; feed prompts through stdin:

```bash
CODEX_HOME="$WORKER_CODEX_HOME" codex-unsafe exec --ignore-rules --cd "$WORKTREE" --json --color never --output-last-message "$LAST" < "$PROMPT" >> "$LOG" 2>&1
```

If this fails, use the real `codex` binary with explicit danger flag in a known-safe order, but preserve the same external worktree checks.

## Worker appears stuck

- Check PID.
- Check worker exit artifact (`workers/<task>.exit.json`).
- Check log file growth.
- Check last-message file.
- Check whether Codex is waiting for auth or network.
- If PID is dead and no exit artifact exists, treat the worker as `unknown_dead` and inspect logs before retrying.
- Do not blindly start duplicate workers on the same worktree.

## Review fails

Generate a revision prompt with only blocker findings. Rerun same worktree if safe. Abort after attempt cap.

## Merge conflicts

Stop automatic integration. Either resolve manually as Commander or spawn a conflict worker with a narrow prompt in the integration worktree.

## Dirty main worktree

Do not overwrite user changes. Worker worktrees are separate, but integration into main requires explicit care. Prefer a local integration branch.
