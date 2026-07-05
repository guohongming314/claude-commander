# claude-commander

`claude-commander` is a user-scope Claude Code skill for commanding Codex CLI workers as worktree-isolated development subagents.

You give a high-level goal. Claude Code acts as Commander: creates a goal contract, learns from references for non-trivial work, writes a spec and task DAG, assigns file/path claims, launches bounded `codex-unsafe` workers in separate git worktrees, monitors logs/state/diffs, assigns reviewers, sends failed work back for revision, and locally integrates reviewed changes.

## Install

Clone this repo, then symlink it into your Claude Code user skills directory:

```bash
git clone git@github.com:guohongming314/claude-commander.git
cd claude-commander
./install.sh
```

`install.sh` symlinks the repo to `~/.claude/skills/claude-commander`, so the
repo stays the source of truth — `git pull` updates the live skill. It backs up
any existing install first.

Requirements: `git`, `codex`, and a `codex-unsafe` wrapper on `PATH`.

## Invocation examples

```text
/claude-commander 把当前 Godot demo 的第一关做成可试玩版本，你自己拆任务，Codex 分工，review 后本地合并。
```

```text
/loop /claude-commander 修复浏览器灰盒原型的交互问题，使用 Codex workers 分工，失败就返工，直到验证通过或需要我决策。
```

## Core guarantees

- Goal-only runs create `goal-contract.md`, `references/reference-brief.md`, `specs/spec.md`, `tasks/task-dag.json`, and `reports/final-report.md` before worker execution.
- Agent fan-out is capped by default: max 3 budgeted AI units concurrently, max 2 implementation workers concurrently, max 1 researcher/spec/reviewer concurrently, max 8 budgeted AI units per run before asking again.
- Same-role/same-topic agents must be reused or continued while they still have useful context; no tiny-task explosion.
- Every Codex worker gets a separate git worktree.
- Default worktrees are user-global under `~/.claude/commander/worktrees/`, not inside the project repo.
- `codex-unsafe` never runs outside a verified Commander-owned worktree.
- Worker prompts forbid push/deploy/publish/global config edits/secrets.
- Worker prompts include file/path claims; merge gate validates claims when the task DAG provides them.
- Worker lifecycle state is persisted under `status/<task>.json`.
- Reviewer pass is required before local integration.
- Reviews are freshness-checked by diff hash; post-review worker changes require re-review.
- Verification evidence is required before merge, or an explicit not-applicable reason.
- Integration is local-only by default.
- Worktrees and logs are kept for audit unless explicitly cleaned.

## Useful commands

```bash
~/.claude/skills/claude-commander/scripts/commander.sh preflight
~/.claude/skills/claude-commander/scripts/commander.sh plan --goal "update README" --dry-run
~/.claude/skills/claude-commander/scripts/commander.sh start --goal "update README" --workers 2
~/.claude/skills/claude-commander/scripts/commander.sh state --run <run-id> --task <task-id> --status ready --note "ready after spec review"
~/.claude/skills/claude-commander/scripts/commander.sh status --run <run-id>
~/.claude/skills/claude-commander/scripts/validate-skill.sh
```

## Notes

`codex-unsafe` on this machine wraps `codex` with `--dangerously-bypass-approvals-and-sandbox`. This skill treats it as high privilege and constrains it externally with git worktrees, path checks, logs, reviews, and local-only merge gates.
