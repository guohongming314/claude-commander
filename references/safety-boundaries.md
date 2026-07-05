# Safety boundaries

`codex-unsafe` is high privilege. On this machine it is a wrapper:

```bash
exec codex "$@" --dangerously-bypass-approvals-and-sandbox
```

That disables Codex approval prompts and sandboxing. Treat every worker launch as externally sandboxed only by your own process, path, git, review, and merge controls. Commander launches workers with a per-worker minimal `HOME`, `CODEX_HOME=$HOME/.codex`, and XDG directories under the Commander run directory. It preserves only allowlisted Codex auth/model-provider/proxy config, writes `[skills] enabled = false` into the generated worker config, refuses to copy the full user `config.toml` fallback, and verifies that user-level `AGENTS.md`, skills, superpowers, sessions, logs, MCP/plugin state, and symlinks back to the real Codex home were not copied before launch. Codex may still create isolated cache/session/plugin directories under the worker `CODEX_HOME` after launch; those are acceptable only if logs do not show reads from the real user Codex home. It also passes `--ignore-rules`, but that flag is defense-in-depth and is not sufficient isolation by itself.

## Non-negotiables

1. Run `codex-unsafe` only inside a verified git worktree.
2. Canonicalize every path before use.
3. Worker worktree path must be under a configured Commander worktree root. Default is `~/.claude/commander/worktrees/<repo-slug>/<run-id>/<task-id>`.
4. `git -C "$WORKTREE" rev-parse --show-toplevel` must equal the canonical worktree path.
5. Cleanup and merge must re-validate that the path is Commander-owned and the current branch matches `commander/<run-id>/<task-id>` before any destructive or integration action.
6. Worker prompt must include the assigned worktree, branch, base ref, allowed scope, forbidden scope, and safety boundaries.
7. Never push, deploy, publish, upload, or call production external services automatically.
8. Never edit `~/.claude`, shell profiles, global git config, credentials, or parent repository from a worker.
9. Never print secrets or broad environment dumps.
10. Never delete user files outside Commander-owned run/worktree directories.
11. Review is mandatory before local integration.
12. Merge only into a local integration branch after fresh review hash and verification evidence checks pass.
13. Stop and mark `FAIL_ABORT` if a worker violates boundaries.

## Red flags in logs or diffs

- `git push`, `gh pr create`, deploy commands, package publish commands.
- Writes outside the worktree.
- Changes to `.ssh`, `.env`, shell profiles, credentials, or `~/.claude`.
- Any read of `~/.codex/superpowers`, `~/.codex/skills`, or other real global Codex state from a worker.
- Broad deletion commands.
- Unrelated formatting across many files.
- Worker claims success but leaves no diff or no verification evidence.

## Commander response to violations

1. Stop the worker process if still running.
2. Preserve logs.
3. Do not merge.
4. Report the exact violation.
5. Ask the user before cleanup if anything outside Commander-owned paths is involved.
