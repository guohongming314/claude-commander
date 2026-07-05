# Runtime adapter profiles

Commander may eventually control multiple AI coding CLIs. Do not assume every tool behaves like Codex. Use an adapter profile for each runtime.

## Adapter fields

Each runtime profile should define:

- `runtime`: stable name, e.g. `codex-unsafe`, `codex-review`, `claude-code`, `gemini-cli`, `aider`, `opencode`.
- `role_fit`: implementer, reviewer, researcher, tester, or integrator.
- `command_template`: exact command shape.
- `cwd_behavior`: how the tool receives the working directory.
- `prompt_input`: stdin, positional argument, file, interactive session, or API.
- `log_format`: jsonl, text transcript, terminal recording, etc.
- `completion_marker`: exit code, output-last-message file, done marker, PR status, etc.
- `stop_method`: PID kill, tmux send-keys, tool-specific stop, or manual.
- `sandbox_expectation`: what external isolation Commander must provide.
- `state_artifacts`: files Commander should persist.
- `known_failure_modes`: auth failures, prompt parsed as argv, waiting for input, context overflow, etc.

## Current supported adapter: codex-unsafe implementer

```yaml
runtime: codex-unsafe
role_fit: [implementer, tester]
command_template: >
  HOME="$WORKER_HOME"
  CODEX_HOME="$WORKER_CODEX_HOME"
  XDG_CONFIG_HOME="$WORKER_XDG_CONFIG_HOME"
  XDG_CACHE_HOME="$WORKER_XDG_CACHE_HOME"
  XDG_DATA_HOME="$WORKER_XDG_DATA_HOME"
  codex-unsafe exec --ignore-rules --cd "$WORKTREE" --json --color never --output-last-message "$LAST_MESSAGE" < "$PROMPT"
cwd_behavior: --cd "$WORKTREE"
prompt_input: stdin
log_format: jsonl plus last-message markdown
completion_marker: process exit + exit artifact JSON
stop_method: process id / process group
sandbox_expectation: Commander-created git worktree + isolated HOME/CODEX_HOME/XDG dirs
state_artifacts:
  - workers/<task>.json
  - workers/<task>.exit.json
  - status/<task>.json
  - logs/<task>.jsonl
  - logs/<task>.last.md
known_failure_modes:
  - auth/config leakage if CODEX_HOME is not isolated
  - prompt parsed incorrectly if passed as positional argv
  - worker edits outside scope if prompt/file claims are weak
  - success summary without verified diff/tests
```

## Current supported adapter: Claude reviewer agent

```yaml
runtime: claude-agent-reviewer
role_fit: [reviewer, researcher]
command_template: Agent tool from Claude Code session
cwd_behavior: read-only by instruction; may inspect worktree paths
prompt_input: structured reviewer prompt
log_format: returned final review text
completion_marker: structured YAML decision
stop_method: harness TaskStop if backgrounded
sandbox_expectation: reviewer must not edit files; Commander validates diff hash afterwards
state_artifacts:
  - reviews/<task>.review.md
  - reviews/<task>.snapshot.json
known_failure_modes:
  - generic review without command evidence
  - review becomes stale when worker diff changes
```

## Adding a new runtime

Before launching a new kind of worker, create a profile here and update launch helpers or a new adapter script. Minimum requirements:

1. Runs only in a Commander-owned worktree or read-only context.
2. Has isolated config/cache/home when the runtime can mutate global state.
3. Has deterministic prompt input and logging.
4. Produces a completion artifact Commander can inspect.
5. Has a stop method.
6. Can be reviewed and integrated through the same diff-hash gate.

If these are missing, do not run the runtime autonomously.
