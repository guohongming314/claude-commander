#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="${CLAUDE_COMMANDER_SKILL_DIR:-$HOME/.claude/skills/claude-commander}"
COMMANDER_HOME="${CLAUDE_COMMANDER_HOME:-$HOME/.claude/commander}"
RUNS_DIR="$COMMANDER_HOME/runs"

usage() {
  cat <<'EOF'
Usage: commander.sh <command> [options]

Commands:
  preflight                              Inspect git/codex/tmux environment without launching workers
  plan --goal TEXT [--dry-run]           Print a goal-only Commander planning scaffold; dry-run creates nothing
  start --goal TEXT [--workers N]        Create a run directory, goal contract, spec, task DAG, and run.json; does not launch workers
        [--base REF] [--autonomy LEVEL]
  state --run RUN --task TASK --status STATUS [--note TEXT]
                                         Record/update lifecycle state for one task
  status --run RUN                       Show run, artifacts, task DAG, task states, and worker status
  monitor --run RUN                      Status plus recent log tails and git status
  review --run RUN --task TASK           Collect review artifacts for one worker
  integrate --run RUN --task TASK [--yes]
                                         Run merge gate; --yes performs local merge after checks
  cleanup --run RUN [--force]            Remove Commander-owned worktrees for a run

Environment:
  CLAUDE_COMMANDER_HOME                  Default: $HOME/.claude/commander
  CLAUDE_COMMANDER_SKILL_DIR             Default: $HOME/.claude/skills/claude-commander
EOF
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }
repo_root() { git rev-parse --show-toplevel 2>/dev/null; }
current_branch() { git branch --show-current 2>/dev/null || true; }
slug() { printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//' | cut -c1-80; }
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
new_run_id() {
  python3 - <<'PY'
import datetime, secrets
stamp = datetime.datetime.now(datetime.UTC).strftime('%Y%m%dT%H%M%S%fZ')
print(f"run-{stamp}-{secrets.token_hex(3)}")
PY
}

resolve_run_dir() {
  local run="${1:-}"
  if [[ -z "$run" ]]; then
    echo "missing --run" >&2
    exit 2
  fi
  if [[ -d "$run" ]]; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$run"
  else
    echo "$RUNS_DIR/$run"
  fi
}

parse_common_run_task() {
  RUN=""
  TASK=""
  EXTRA_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) RUN="${2:?}"; shift 2 ;;
      --task) TASK="${2:?}"; shift 2 ;;
      --yes) EXTRA_ARGS+=("--yes"); shift ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
}

preflight() {
  local root branch codex_path codex_unsafe_path tmux_path
  root="$(repo_root || true)"
  branch="$(current_branch)"
  codex_path="$(command -v codex || true)"
  codex_unsafe_path="$(command -v codex-unsafe || true)"
  tmux_path="$(command -v tmux || true)"

  echo "# Claude Commander preflight"
  echo "time: $(now_utc)"
  echo "repo: ${root:-NOT_A_GIT_REPO}"
  echo "branch: ${branch:-UNKNOWN}"
  echo "codex: ${codex_path:-MISSING}"
  echo "codex-unsafe: ${codex_unsafe_path:-MISSING}"
  echo "tmux: ${tmux_path:-MISSING}"

  if [[ -n "$codex_path" ]]; then
    echo "codex_version: $(codex --version 2>/dev/null || true)"
  fi
  if [[ -n "$codex_unsafe_path" ]]; then
    echo "codex_unsafe_version: $(codex-unsafe --version 2>/dev/null || true)"
    if [[ -f "$codex_unsafe_path" ]]; then
      echo "codex_unsafe_wrapper:"
      sed -n '1,5p' "$codex_unsafe_path" | sed 's/^/  /'
    fi
  fi

  if [[ -n "$root" ]]; then
    echo "git_status_short:"
    git -C "$root" status --short | sed 's/^/  /' || true
  fi

  [[ -n "$root" ]] || { echo "ERROR: not in a git repository" >&2; exit 1; }
  need_cmd git || { echo "ERROR: git missing" >&2; exit 1; }
  need_cmd codex || { echo "ERROR: codex missing" >&2; exit 1; }
  need_cmd codex-unsafe || { echo "ERROR: codex-unsafe missing" >&2; exit 1; }
}

write_run_scaffold() {
  local run_dir="$1" run_id="$2" goal="$3" root="$4" branch="$5" base="$6" workers="$7" repo_slug="$8" autonomy="$9"
  mkdir -p "$run_dir/prompts" "$run_dir/logs" "$run_dir/workers" "$run_dir/reviews" "$run_dir/reports" "$run_dir/diffs" "$run_dir/references" "$run_dir/specs" "$run_dir/tasks" "$run_dir/status" "$run_dir/integration"
  python3 - "$run_dir" "$run_id" "$goal" "$root" "$branch" "$base" "$workers" "$repo_slug" "$autonomy" <<'PY'
import json, sys, datetime, textwrap
from pathlib import Path
run_dir = Path(sys.argv[1])
run_id, goal, root, branch, base, workers, repo_slug, autonomy = sys.argv[2:]
now = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace('+00:00','Z')
artifacts = {
    "goal_contract": "goal-contract.md",
    "reference_brief": "references/reference-brief.md",
    "spec": "specs/spec.md",
    "task_dag": "tasks/task-dag.json",
    "final_report": "reports/final-report.md",
}
run = {
    "run_id": run_id,
    "goal": goal,
    "repo_root": root,
    "repo_slug": repo_slug,
    "started_at": now,
    "base_ref": base,
    "starting_branch": branch,
    "requested_workers": int(workers),
    "status": "created",
    "autonomy_level": autonomy,
    "worktree_default": "user-global",
    "artifacts": artifacts,
    "lifecycle_states": [
        "planned", "ready", "running", "blocked_waiting_input", "blocked_failed_check",
        "succeeded_unreviewed", "review_failed_revise", "review_passed", "merged_local", "failed_abort"
    ],
    "terminal_conditions": [
        "all tasks reviewed and locally integrated",
        "blocked on genuine user-owned decision",
        "safety boundary hit",
        "max attempts or review cycles exhausted",
        "verification cannot safely run and no substitute exists",
    ],
    "safety": {"push_allowed": False, "deploy_allowed": False, "publish_allowed": False},
    "budgets": {
        "max_concurrent_total": 3,
        "max_concurrent_by_role": {"researcher": 1, "spec": 1, "implementer": min(int(workers), 2), "reviewer": 1, "test": 1, "integrator": 1},
        "max_launched_per_phase": 5,
        "max_launched_per_run_before_reapproval": 8,
        "max_first_dag_leaf_implementation_tasks": 6,
        "max_ready_tasks_launched_at_once": 2,
        "same_role_reuse_required": True,
        "requires_user_approval_to_exceed": True,
    },
}
(run_dir / "run.json").write_text(json.dumps(run, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

contract = f"""# Goal contract: {run_id}

## Goal

{goal}

## Definition of done

- Commander has explored repo context and relevant memory/instructions.
- Non-trivial work has a reference brief or an explicit skip reason.
- A spec and task DAG exist before implementation workers launch.
- Each worker has bounded scope, file/path claims, forbidden paths, acceptance criteria, and verification commands.
- Every worker diff is inspected against `{base}`.
- Verification evidence is captured for each task, or `NOT_APPLICABLE` has a concrete reason.
- A read-only review passes with a matching diff hash before integration.
- Local integration is attempted only after review gates pass and main tracked changes are safe.
- Final report states what passed, failed, merged, or was skipped.

## Non-goals

- Do not push, open PRs, deploy, publish, or call production external services unless separately authorized.
- Do not overwrite unrelated user changes in the main worktree.
- Do not treat worker summaries as evidence.

## Forbidden actions

- Running `codex-unsafe` outside a verified Commander-owned worktree.
- Editing `~/.claude`, shell profiles, global git config, credentials, or unrelated user files from Codex workers.
- Printing secrets or environment variables.
- Deleting files outside Commander-owned worktrees/logs.

## Autonomy level

`{autonomy}`. Commander should infer implementation details, ask only user-owned decisions, and stop only at terminal conditions.

## Agent budget

Default budget for this run:

- Max concurrent budgeted AI units: 3 total.
- Max concurrent implementers requested for this run: {min(int(workers), 2)}.
- Max researcher/spec/reviewer agents: 1 each.
- Max launched per phase: 5.
- Max launched per run before asking again: 8.
- Same-role/same-topic agents must be reused or continued instead of duplicated while they still have useful context.
- Raising these caps requires explicit user approval recorded in this file and `run.json`.

## Required evidence

- `run.json`
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
"""
(run_dir / "goal-contract.md").write_text(contract, encoding="utf-8")

reference = f"""# Reference brief: {goal}

## Sources studied

- TODO: Add 2-5 relevant public examples/docs, or record an explicit skip reason.

## Patterns to adopt

- TODO

## Patterns to avoid

- TODO

## Decisions for this repo

- TODO

## Impact on worker tasks

- TODO

## Licensing/source hygiene

- Treat references as learning material by default. Do not copy substantial external code/assets/text without license compatibility and attribution.

## Skipped or uncertain areas

- TODO
"""
(run_dir / "references" / "reference-brief.md").write_text(reference, encoding="utf-8")

spec = f"""# Commander spec: {goal}

## Context summary

- Repo root: `{root}`
- Base ref: `{base}`
- Starting branch: `{branch}`
- Requested workers: `{workers}`

## Proposed approach

TODO: Synthesize repo context and reference learning into a concrete approach before launching workers.

## Task DAG summary

See `tasks/task-dag.json`.

## File/path claim strategy

- `owned`: paths a task may edit.
- `shared`: paths requiring coordination/review.
- `read_only`: paths a task may inspect only.
- `forbidden`: paths a task must not touch.

## Verification plan

TODO: List commands and expected evidence for each task.

## Review rubric

- Correctness bugs
- Scope/file-claim violations
- Missing verification
- Safety boundary violations
- Simplicity/maintainability
- Goal contract and reference/spec compliance

## Rollback/integration plan

- Keep worker worktrees and logs for audit.
- Commit worker diffs only through the merge gate.
- Merge only into local `commander/{run_id}/integration` unless separately authorized.
"""
(run_dir / "specs" / "spec.md").write_text(spec, encoding="utf-8")

dag = {
    "run_id": run_id,
    "goal": goal,
    "created_at": now,
    "schema_version": 1,
    "budgets": run["budgets"],
    "states": run["lifecycle_states"],
    "tasks": [
        {
            "task_id": "R001-reference-brief",
            "role": "researcher",
            "phase": 1,
            "consumes_agent_budget": False,
            "budget_note": "Use WebSearch/WebFetch in main context first; launch at most one researcher agent only if needed.",
            "state": "planned",
            "depends_on": [],
            "file_claims": {
                "owned": ["<run>/references/reference-brief.md"],
                "shared": [],
                "read_only": ["repo", "public references"],
                "forbidden": ["credentials", "production systems"]
            },
            "acceptance_criteria": ["Reference brief exists or skip reason is documented"],
            "verification": ["Manual Commander review of references/reference-brief.md"],
            "retry_limit": 1,
        },
        {
            "task_id": "S001-spec-and-dag",
            "role": "spec",
            "phase": 1,
            "consumes_agent_budget": False,
            "budget_note": "Do in main Commander context unless spec work exceeds current context capacity.",
            "state": "planned",
            "depends_on": ["R001-reference-brief"],
            "file_claims": {
                "owned": ["<run>/specs/spec.md", "<run>/tasks/task-dag.json"],
                "shared": [],
                "read_only": ["repo"],
                "forbidden": ["repo writes before worker launch"]
            },
            "acceptance_criteria": ["Spec and task DAG define implementable worker tasks with file claims and verification"],
            "verification": ["Manual Commander review of specs/spec.md and tasks/task-dag.json"],
            "retry_limit": 1,
        }
    ]
}
(run_dir / "tasks" / "task-dag.json").write_text(json.dumps(dag, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

report = f"""# Commander final report: {run_id}

## Goal

{goal}

## Status

Not completed yet. This report is a scaffold; update it after workers, reviews, verification, and integration.

## Workers launched

TODO

## Reviews

TODO

## Integration

TODO

## Verification

TODO

## Remaining risks

TODO

## Next actions

TODO

Note: no push/deploy/publish was performed unless separately authorized.
"""
(run_dir / "reports" / "final-report.md").write_text(report, encoding="utf-8")
PY
}

plan_cmd() {
  local goal="" dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --goal) goal="${2:?}"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
  [[ -n "$goal" ]] || { echo "missing --goal" >&2; exit 2; }

  cat <<EOF
# Commander goal-only plan scaffold

dry_run: $dry_run
goal: $goal

Required sequence before worker launch:
1. Preflight repo/codex/worktree environment.
2. Create a goal contract with definition of done, non-goals, forbidden actions, evidence, autonomy level, and stop conditions.
3. Learn from references for non-trivial work and save references/reference-brief.md.
4. Produce specs/spec.md and tasks/task-dag.json.
5. Assign file/path claims and an agent budget plan for every planned worker.
6. Reuse same-role agents while they have useful context; do not fan out same-role tiny tasks.
7. Launch workers only for ready tasks with non-overlapping claims, max 2 implementers and max 3 total budgeted AI units concurrently by default.
8. Capture diffs/hashes, run verification, review with severity and matching diff hash.
9. Integrate locally only through gate-merge.sh.

Create a run scaffold with:
  $SKILL_DIR/scripts/commander.sh start --goal "$(printf '%s' "$goal" | sed 's/"/\\"/g')"

No worktrees or workers were created by this plan command.
EOF
}

start_cmd() {
  local goal="" workers="2" base root branch run_id="" run_dir="" repo_slug attempt autonomy="supervised-autonomous"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --goal) goal="${2:?}"; shift 2 ;;
      --workers) workers="${2:?}"; shift 2 ;;
      --base) base="${2:?}"; shift 2 ;;
      --autonomy) autonomy="${2:?}"; shift 2 ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
  [[ -n "$goal" ]] || { echo "missing --goal" >&2; exit 2; }
  if ! [[ "$workers" =~ ^[0-9]+$ ]]; then
    echo "--workers must be a positive integer" >&2
    exit 2
  fi
  if [[ "$workers" -lt 1 ]]; then
    echo "--workers must be at least 1" >&2
    exit 2
  fi
  if [[ "$workers" -gt 2 && "${CLAUDE_COMMANDER_ALLOW_LARGE_FANOUT:-0}" != "1" ]]; then
    echo "refusing --workers $workers: default cap is 2 implementation workers; ask the user and set CLAUDE_COMMANDER_ALLOW_LARGE_FANOUT=1 only after explicit approval" >&2
    exit 1
  fi
  root="$(repo_root)"
  branch="$(current_branch)"
  base="${base:-HEAD}"
  repo_slug="$(slug "$(basename "$root")")"
  mkdir -p "$RUNS_DIR"
  for attempt in {1..10}; do
    run_id="$(new_run_id)"
    run_dir="$RUNS_DIR/$run_id"
    if mkdir "$run_dir" 2>/dev/null; then
      break
    fi
    run_id=""
  done
  [[ -n "$run_id" ]] || { echo "failed to allocate unique run id" >&2; exit 1; }
  write_run_scaffold "$run_dir" "$run_id" "$goal" "$root" "$branch" "$base" "$workers" "$repo_slug" "$autonomy"
  echo "$run_id"
  echo "Run directory: $run_dir"
  echo "Goal contract: $run_dir/goal-contract.md"
  echo "Reference brief: $run_dir/references/reference-brief.md"
  echo "Spec: $run_dir/specs/spec.md"
  echo "Task DAG: $run_dir/tasks/task-dag.json"
}

state_cmd() {
  local RUN="" TASK="" STATUS="" NOTE="" run_dir task_safe state_file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) RUN="${2:?}"; shift 2 ;;
      --task) TASK="${2:?}"; shift 2 ;;
      --status) STATUS="${2:?}"; shift 2 ;;
      --note) NOTE="${2:?}"; shift 2 ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
  [[ -n "$RUN" && -n "$TASK" && -n "$STATUS" ]] || { echo "missing --run/--task/--status" >&2; exit 2; }
  run_dir="$(resolve_run_dir "$RUN")"
  [[ -d "$run_dir" ]] || { echo "run not found: $run_dir" >&2; exit 1; }
  mkdir -p "$run_dir/status"
  task_safe="$(slug "$TASK")"
  state_file="$run_dir/status/$task_safe.json"
  python3 - "$state_file" "$TASK" "$STATUS" "$NOTE" <<'PY'
import json, sys, datetime
path, task, status, note = sys.argv[1:]
valid = {"planned", "ready", "running", "blocked_waiting_input", "blocked_failed_check", "succeeded_unreviewed", "review_failed_revise", "review_passed", "merged_local", "failed_abort"}
if status not in valid:
    print(f"invalid status: {status}", file=sys.stderr)
    raise SystemExit(2)
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    data = {"task_id": task, "history": []}
now = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace('+00:00','Z')
data["task_id"] = task
data["status"] = status
data["updated_at"] = now
if note:
    data["note"] = note
data.setdefault("history", []).append({"status": status, "note": note, "at": now})
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
  echo "state_file: $state_file"
}

status_cmd() {
  local RUN="" run_dir
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) RUN="${2:?}"; shift 2 ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
  run_dir="$(resolve_run_dir "$RUN")"
  [[ -d "$run_dir" ]] || { echo "run not found: $run_dir" >&2; exit 1; }
  echo "# Run status: $(basename "$run_dir")"
  [[ -f "$run_dir/run.json" ]] && python3 -m json.tool "$run_dir/run.json" || true
  echo
  echo "# Core artifacts"
  for artifact in goal-contract.md references/reference-brief.md specs/spec.md tasks/task-dag.json reports/final-report.md; do
    if [[ -f "$run_dir/$artifact" ]]; then
      echo "- present: $artifact"
    else
      echo "- missing: $artifact"
    fi
  done
  echo
  echo "# Task DAG"
  if [[ -f "$run_dir/tasks/task-dag.json" ]]; then
    python3 - "$run_dir/tasks/task-dag.json" <<'PY'
import json, sys
data=json.load(open(sys.argv[1], encoding='utf-8'))
for task in data.get('tasks', []):
    deps=','.join(task.get('depends_on', [])) or '-'
    print(f"- {task.get('task_id')} [{task.get('state','unknown')}] role={task.get('role')} depends_on={deps}")
PY
  else
    echo "(no task DAG)"
  fi
  echo
  echo "# Task state files"
  shopt -s nullglob
  local state
  for state in "$run_dir"/status/*.json; do
    python3 - "$state" <<'PY'
import json, sys
data=json.load(open(sys.argv[1], encoding='utf-8'))
print(f"- {data.get('task_id')}: {data.get('status')} updated_at={data.get('updated_at')} note={data.get('note','')}")
PY
  done
  echo
  echo "# Workers"
  local worker
  for worker in "$run_dir"/workers/*.json; do
    [[ "$worker" == *.exit.json ]] && continue
    python3 - "$worker" <<'PY'
import json, os, sys
p=sys.argv[1]
data=json.load(open(p, encoding='utf-8'))
pid=data.get('pid')
alive=False
if pid:
  try:
    os.kill(int(pid), 0); alive=True
  except OSError:
    alive=False
exit_path=data.get('exit_path') or ''
exit_data=None
if exit_path and os.path.exists(exit_path):
  try:
    exit_data=json.load(open(exit_path, encoding='utf-8'))
  except Exception:
    exit_data={"status":"exit_unreadable"}
if exit_data:
  effective=exit_data.get('status','exited')
  exit_code=exit_data.get('exit_code','')
elif data.get('status') == 'running' and not alive:
  effective='unknown_dead'
  exit_code=''
else:
  effective=data.get('status','unknown')
  exit_code=''
extra=f" exit_code={exit_code}" if exit_code != '' else ''
summary=(data.get('task_summary') or '').strip()
if len(summary) > 180:
  summary = summary[:177] + '...'
print(f"- {data.get('task_id')}: {summary or '(no summary)'}")
print(f"  status={effective}{extra} pid={pid} alive={alive}")
print(f"  branch={data.get('branch')}")
print(f"  prompt={data.get('prompt_path')}")
print(f"  worktree={data.get('worktree_path')}")
PY
  done
}

monitor_cmd() {
  local RUN="" run_dir
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) RUN="${2:?}"; shift 2 ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
  run_dir="$(resolve_run_dir "$RUN")"
  "$0" status --run "$run_dir"
  echo
  echo "# Worker details"
  shopt -s nullglob
  local worker wt log exit_path last summary
  for worker in "$run_dir"/workers/*.json; do
    [[ "$worker" == *.exit.json ]] && continue
    wt="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("worktree_path", ""))' "$worker")"
    log="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("log_path", ""))' "$worker")"
    exit_path="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("exit_path", ""))' "$worker")"
    last="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("last_message_path", ""))' "$worker")"
    summary="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("task_summary", ""))' "$worker")"
    echo
    echo "## $(basename "$worker" .json)"
    if [[ -n "$summary" ]]; then
      echo "task_summary: $summary"
    fi
    if [[ -d "$wt" ]]; then
      echo "git_status:"
      git -C "$wt" status --short | sed 's/^/  /' || true
    fi
    if [[ -f "$exit_path" ]]; then
      echo "exit:"
      python3 -m json.tool "$exit_path" | sed 's/^/  /' || true
    fi
    if [[ -f "$last" ]]; then
      echo "last_message: $last"
    fi
    if [[ -f "$log" ]]; then
      echo "recent_log:"
      tail -n 20 "$log" | sed 's/^/  /' || true
    fi
  done
}

review_cmd() {
  parse_common_run_task "$@"
  "$SKILL_DIR/scripts/review-worker.sh" --run "$RUN" --task "$TASK"
}

integrate_cmd() {
  parse_common_run_task "$@"
  "$SKILL_DIR/scripts/gate-merge.sh" --run "$RUN" --task "$TASK" "${EXTRA_ARGS[@]}"
}

cleanup_cmd() {
  "$SKILL_DIR/scripts/cleanup-worktrees.sh" "$@"
}

cmd="${1:-}"
[[ -n "$cmd" ]] || { usage; exit 2; }
shift || true
case "$cmd" in
  preflight) preflight "$@" ;;
  plan) plan_cmd "$@" ;;
  start) start_cmd "$@" ;;
  state) state_cmd "$@" ;;
  status) status_cmd "$@" ;;
  monitor) monitor_cmd "$@" ;;
  review) review_cmd "$@" ;;
  integrate) integrate_cmd "$@" ;;
  cleanup) cleanup_cmd "$@" ;;
  -h|--help|help) usage ;;
  *) echo "unknown command: $cmd" >&2; usage; exit 2 ;;
esac
