#!/usr/bin/env bash
set -euo pipefail

COMMANDER_HOME="${CLAUDE_COMMANDER_HOME:-$HOME/.claude/commander}"
RUNS_DIR="$COMMANDER_HOME/runs"

usage() {
  cat <<'EOF'
Usage: cleanup-worktrees.sh --run RUN [--force]

Removes validated Commander-owned git worktrees recorded in a run. Refuses dirty worktrees unless --force is passed.
EOF
}

realpath_py() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
json_get() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], ""))' "$1" "$2"; }
slug() { printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//' | cut -c1-80; }

validate_worker_worktree() {
  local repo="$1" run_id="$2" task_safe="$3" wt="$4" branch="$5"
  local repo_top wt_real top top_real project_allowed global_allowed current_branch
  repo_top="$(git -C "$repo" rev-parse --show-toplevel)"
  wt_real="$(realpath_py "$wt")"
  project_allowed="$(realpath_py "$repo_top/.claude/commander/worktrees")"
  global_allowed="$(realpath_py "$COMMANDER_HOME/worktrees")"
  case "$wt_real" in
    "$project_allowed"/*|"$global_allowed"/*) ;;
    *) echo "refusing unsafe worktree path: $wt_real" >&2; return 1 ;;
  esac
  [[ "$wt_real" != "$project_allowed" && "$wt_real" != "$global_allowed" ]] || { echo "refusing broad worktree root: $wt_real" >&2; return 1; }
  [[ -d "$wt_real" ]] || { echo "worktree missing: $wt_real" >&2; return 1; }
  top="$(git -C "$wt_real" rev-parse --show-toplevel)"
  top_real="$(realpath_py "$top")"
  [[ "$top_real" == "$wt_real" ]] || { echo "git top-level mismatch: $top_real != $wt_real" >&2; return 1; }
  current_branch="$(git -C "$wt_real" branch --show-current)"
  [[ "$current_branch" == "$branch" ]] || { echo "branch mismatch: $current_branch != $branch" >&2; return 1; }
  [[ "$branch" == "commander/$run_id/$task_safe" ]] || { echo "unexpected worker branch: $branch" >&2; return 1; }
}

RUN=""; FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; shift 2 ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done
[[ -n "$RUN" ]] || { usage; exit 2; }
if [[ -d "$RUN" ]]; then RUN_DIR="$(realpath_py "$RUN")"; RUN_ID="$(basename "$RUN_DIR")"; else RUN_ID="$RUN"; RUN_DIR="$RUNS_DIR/$RUN"; fi
RUN_JSON="$RUN_DIR/run.json"
[[ -f "$RUN_JSON" ]] || { echo "run.json not found: $RUN_JSON" >&2; exit 1; }
[[ -d "$RUN_DIR/workers" ]] || { echo "workers directory not found: $RUN_DIR/workers" >&2; exit 1; }
REPO="$(json_get "$RUN_JSON" repo_root)"
[[ -n "$REPO" && -d "$REPO" ]] || { echo "repo root missing: $REPO" >&2; exit 1; }

shopt -s nullglob
FAILED=0
for worker in "$RUN_DIR"/workers/*.json; do
  [[ "$worker" == *.exit.json ]] && continue
  WT="$(json_get "$worker" worktree_path)"
  BRANCH="$(json_get "$worker" branch)"
  TASK_SAFE="$(json_get "$worker" task_id)"
  TASK_SAFE="${TASK_SAFE:-$(slug "$(basename "$worker" .json)")}"
  [[ -n "$WT" ]] || continue
  if [[ ! -d "$WT" ]]; then
    echo "skip missing worktree: $WT"
    continue
  fi
  if ! validate_worker_worktree "$REPO" "$RUN_ID" "$TASK_SAFE" "$WT" "$BRANCH"; then
    echo "refusing cleanup for invalid worker state: $worker" >&2
    FAILED=1
    continue
  fi
  STATUS="$(git -C "$WT" status --porcelain || true)"
  if [[ -n "$STATUS" && "$FORCE" != true ]]; then
    echo "refusing dirty worktree without --force: $WT" >&2
    git -C "$WT" status --short >&2 || true
    FAILED=1
    continue
  fi
  echo "removing worktree: $WT"
  if [[ "$FORCE" == true ]]; then
    git -C "$WT" reset --hard >/dev/null 2>&1 || true
    git -C "$WT" clean -fd >/dev/null 2>&1 || true
    git -C "$WT" worktree remove --force "$WT" 2>/dev/null || git worktree remove --force "$WT"
  else
    git -C "$WT" worktree remove "$WT" 2>/dev/null || git worktree remove "$WT"
  fi
done
exit "$FAILED"
