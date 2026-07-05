#!/usr/bin/env bash
set -euo pipefail

COMMANDER_HOME="${CLAUDE_COMMANDER_HOME:-$HOME/.claude/commander}"
RUNS_DIR="$COMMANDER_HOME/runs"

usage() {
  cat <<'EOF'
Usage: gate-merge.sh --run RUN --task TASK [--yes]

Checks whether a worker can merge into a local integration branch. Without --yes, prints the decision only.
Gate checks include: Commander-owned worktree, reviewed diff hash, verification evidence, safety scan, and task-DAG file claims when present.
EOF
}

realpath_py() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
json_get() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], ""))' "$1" "$2"; }
slug() { printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//' | cut -c1-80; }
sha256_file() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"; }

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

snapshot_current_diff() {
  local wt="$1" base="$2" task_safe="$3" out_diff="$4" out_status="$5" out_stat="$6" out_paths="$7"
  local alt_index
  alt_index="$RUN_DIR/diffs/$task_safe.gate.index"
  rm -f "$alt_index"
  git -C "$wt" status --short > "$out_status"
  GIT_INDEX_FILE="$alt_index" git -C "$wt" read-tree HEAD
  GIT_INDEX_FILE="$alt_index" git -C "$wt" add -A
  GIT_INDEX_FILE="$alt_index" git -C "$wt" diff --cached --stat "$base" -- > "$out_stat" || true
  GIT_INDEX_FILE="$alt_index" git -C "$wt" diff --cached --name-only "$base" -- > "$out_paths" || true
  GIT_INDEX_FILE="$alt_index" git -C "$wt" diff --cached "$base" -- > "$out_diff" || true
  sha256_file "$out_diff"
}

update_task_state() {
  local task="$1" status="$2" note="$3" state_dir state_file
  state_dir="$RUN_DIR/status"
  state_file="$state_dir/$task.json"
  mkdir -p "$state_dir"
  python3 - "$state_file" "$task" "$status" "$note" <<'PY'
import json, sys, datetime
path, task, status, note = sys.argv[1:]
try:
    data = json.load(open(path, encoding='utf-8'))
except Exception:
    data = {'task_id': task, 'history': []}
now = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace('+00:00','Z')
data['task_id'] = task
data['status'] = status
data['updated_at'] = now
if note:
    data['note'] = note
data.setdefault('history', []).append({'status': status, 'note': note, 'at': now})
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
}

RUN=""; TASK=""; YES=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; shift 2 ;;
    --task) TASK="${2:?}"; shift 2 ;;
    --yes) YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done
[[ -n "$RUN" && -n "$TASK" ]] || { usage; exit 2; }
if [[ -d "$RUN" ]]; then RUN_DIR="$(realpath_py "$RUN")"; RUN_ID="$(basename "$RUN_DIR")"; else RUN_ID="$RUN"; RUN_DIR="$RUNS_DIR/$RUN"; fi
TASK_SAFE="$(slug "$TASK")"
RUN_JSON="$RUN_DIR/run.json"
WORKER_JSON="$RUN_DIR/workers/$TASK_SAFE.json"
[[ -f "$RUN_JSON" && -f "$WORKER_JSON" ]] || { echo "run/worker state missing" >&2; exit 1; }

REPO="$(json_get "$RUN_JSON" repo_root)"
BASE="$(json_get "$WORKER_JSON" base_ref)"
BRANCH="$(json_get "$WORKER_JSON" branch)"
WT="$(json_get "$WORKER_JSON" worktree_path)"
LOG="$(json_get "$WORKER_JSON" log_path)"
LAST="$(json_get "$WORKER_JSON" last_message_path)"
REVIEW_FILE=""
for cand in "$RUN_DIR/reviews/$TASK_SAFE.review.md" "$RUN_DIR/reviews/$TASK_SAFE.codex-review.md"; do
  [[ -f "$cand" ]] && { REVIEW_FILE="$cand"; break; }
done
INTEGRATION="commander/$RUN_ID/integration"
GATE_DIFF="$RUN_DIR/diffs/$TASK_SAFE.gate.diff"
GATE_STATUS="$RUN_DIR/diffs/$TASK_SAFE.gate.status.txt"
GATE_STAT="$RUN_DIR/diffs/$TASK_SAFE.gate.stat.txt"
GATE_PATHS="$RUN_DIR/diffs/$TASK_SAFE.gate.paths.txt"
TASK_DAG="$RUN_DIR/tasks/task-dag.json"

command -v git >/dev/null || { echo "git missing" >&2; exit 1; }
mkdir -p "$RUN_DIR/diffs"
validate_worker_worktree "$REPO" "$RUN_ID" "$TASK_SAFE" "$WT" "$BRANCH"
CURRENT_DIFF_SHA="$(snapshot_current_diff "$WT" "$BASE" "$TASK_SAFE" "$GATE_DIFF" "$GATE_STATUS" "$GATE_STAT" "$GATE_PATHS")"

printf '# Merge gate\n'
printf 'run: %s\n' "$RUN_ID"
printf 'task: %s\n' "$TASK_SAFE"
printf 'branch: %s\n' "$BRANCH"
printf 'integration: %s\n' "$INTEGRATION"
printf 'current_diff_sha256: %s\n' "$CURRENT_DIFF_SHA"
printf 'changed_paths_file: %s\n' "$GATE_PATHS"

if [[ -n "$REVIEW_FILE" ]]; then
  echo "review_file: $REVIEW_FILE"
else
  echo "decision: REVISE"
  echo "reason: missing review file; expected one of:"
  echo "  $RUN_DIR/reviews/$TASK_SAFE.review.md"
  echo "  $RUN_DIR/reviews/$TASK_SAFE.codex-review.md"
  update_task_state "$TASK_SAFE" "succeeded_unreviewed" "merge gate found missing review"
  exit 1
fi

python3 - "$REVIEW_FILE" "$CURRENT_DIFF_SHA" <<'PY'
import re, sys
path, current = sys.argv[1:]
text = open(path, encoding='utf-8', errors='replace').read()
def field(name):
    m = re.search(rf'^\s*{re.escape(name)}\s*:\s*["\']?([^"\'\n#]+)', text, re.M)
    return m.group(1).strip() if m else ''
decision = field('decision')
if decision not in {'PASS', 'PASS_WITH_NOTES'}:
    print('decision: REVISE')
    print(f'reason: review decision is not pass: {decision or "MISSING"}')
    sys.exit(1)
reviewed = field('reviewed_diff_sha256')
if not reviewed:
    print('decision: REVISE')
    print('reason: review missing reviewed_diff_sha256')
    sys.exit(1)
if reviewed != current:
    print('decision: REVISE')
    print('reason: worker diff changed after review; rerun review')
    print(f'reviewed_diff_sha256: {reviewed}')
    print(f'current_diff_sha256: {current}')
    sys.exit(1)
verification = field('verification_status')
if verification == 'PASS':
    if not re.search(r'^\s*exit_code\s*:\s*0\s*$', text, re.M):
        print('decision: REVISE')
        print('reason: verification_status PASS requires exit_code: 0 evidence')
        sys.exit(1)
elif verification == 'NOT_APPLICABLE':
    if not re.search(r'^\s*verification_evidence\s*:', text, re.M) or not re.search(r'(?i)(not[_ -]?applicable|reason|summary\s*:)', text):
        print('decision: REVISE')
        print('reason: verification_status NOT_APPLICABLE requires evidence/reason')
        sys.exit(1)
else:
    print('decision: REVISE')
    print(f'reason: verification_status is not acceptable: {verification or "MISSING"}')
    sys.exit(1)
print('review: pass')
print(f'verification_status: {verification}')
PY

python3 - "$TASK_DAG" "$TASK_SAFE" "$GATE_PATHS" <<'PY'
import fnmatch, json, os, sys

dag_path, task_id, paths_file = sys.argv[1:]
if not os.path.exists(dag_path):
    print('claim_check: skipped (no task DAG)')
    raise SystemExit(0)
try:
    dag = json.load(open(dag_path, encoding='utf-8'))
except Exception as exc:
    print('decision: REVISE')
    print(f'reason: cannot read task DAG for file-claim check: {exc}')
    raise SystemExit(1)
tasks = dag.get('tasks', []) if isinstance(dag, dict) else []
task = next((t for t in tasks if str(t.get('task_id')) == task_id), None)
if not task:
    print('claim_check: skipped (task not in DAG)')
    raise SystemExit(0)
claims = task.get('file_claims') or task.get('claims') or {}
allowed = []
for key in ('owned', 'shared'):
    vals = claims.get(key, []) if isinstance(claims, dict) else []
    if isinstance(vals, str):
        vals = [vals]
    allowed.extend(str(v) for v in vals)
allowed = [a for a in allowed if a and not a.startswith('<run>')]
if not allowed:
    print('claim_check: skipped (no repo owned/shared claims)')
    raise SystemExit(0)
if any(a in {'*', '<repo>', '<repo>/**', 'repo'} for a in allowed):
    print('claim_check: pass (broad repo claim)')
    raise SystemExit(0)
changed = [p.strip() for p in open(paths_file, encoding='utf-8', errors='replace') if p.strip()]

def norm(pattern):
    pattern = pattern.strip().replace('\\', '/')
    for prefix in ('<repo>/', './'):
        if pattern.startswith(prefix):
            pattern = pattern[len(prefix):]
    return pattern.lstrip('/')

def matches(path, pattern):
    pattern = norm(pattern)
    if not pattern:
        return False
    if pattern.endswith('/**'):
        return path == pattern[:-3].rstrip('/') or path.startswith(pattern[:-3].rstrip('/') + '/')
    if pattern.endswith('/'):
        return path.startswith(pattern)
    if any(ch in pattern for ch in '*?['):
        return fnmatch.fnmatch(path, pattern)
    return path == pattern or path.startswith(pattern.rstrip('/') + '/')
violations = []
for path in changed:
    path = norm(path)
    if not any(matches(path, pat) for pat in allowed):
        violations.append(path)
if violations:
    print('decision: REVISE')
    print('reason: worker diff changes paths outside task file claims')
    print('allowed_claims:')
    for pat in allowed:
        print(f'  - {pat}')
    print('violating_paths:')
    for path in violations:
        print(f'  - {path}')
    raise SystemExit(1)
print('claim_check: pass')
PY

python3 - "$LOG" "$LAST" "$GATE_DIFF" "$GATE_STATUS" <<'PY'
import os, re, sys
paths = [p for p in sys.argv[1:] if p and os.path.exists(p)]
cmd_patterns = [
    r'\bgit\s+push\b', r'\bgh\s+pr\s+create\b', r'\bgh\s+release\b',
    r'\b(?:npm|pnpm|yarn)\s+publish\b', r'\bvercel\s+deploy\b',
    r'\bfirebase\s+deploy\b', r'\bfly\s+deploy\b', r'\brailway\s+up\b',
    r'\bdocker\s+push\b', r'\bgit\s+config\s+--global\b',
    r'(^|[;&|`$()\s])printenv(\s|$)', r'(^|[;&|`$()\s])env(\s|$)',
    r'\brm\s+-rf\s+(?:/|~|\.\./)',
]
path_patterns = [r'~?/\.claude\b', r'~?/\.ssh\b', r'\.aws/credentials\b', r'\.npmrc\b']
ignore_words = ('do not', 'never ', 'forbid', 'forbidden', '不允许', '不要', '禁止', 'off-limits')
for path in paths:
    text = open(path, encoding='utf-8', errors='replace').read().splitlines()
    for i, line in enumerate(text, 1):
        lower = line.lower()
        command_like = not any(w in lower for w in ignore_words)
        pats = cmd_patterns if command_like else []
        if path.endswith(('.diff', '.txt')):
            pats = pats + path_patterns
        for pat in pats:
            if re.search(pat, line, re.I):
                print('decision: ABORT')
                print(f'reason: suspicious safety-boundary evidence in {path}:{i}: {line[:200]}')
                sys.exit(1)
print('safety_scan: pass')
PY

if [[ "$YES" != true ]]; then
  update_task_state "$TASK_SAFE" "review_passed" "merge gate dry-run passed"
  echo "decision: MERGE_LOCAL_DRY_RUN"
  echo "reason: pass checks; rerun with --yes to merge locally"
  exit 0
fi

# Guard: never switch the main repo branch on top of the user's uncommitted work.
# Only tracked modifications (staged or unstaged) can be clobbered/carried by a
# branch switch; untracked files survive a switch, so they must not block integration.
if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
  update_task_state "$TASK_SAFE" "blocked_waiting_input" "main repo has uncommitted tracked changes"
  echo "decision: BLOCKED"
  echo "reason: main repo has uncommitted changes to tracked files; commit or stash them before local integration"
  git -C "$REPO" status --short | sed 's/^/  /'
  exit 1
fi

# Workers may leave changes uncommitted in the worktree. Commit them onto the
task_branch_had_work=false
if [[ -n "$(git -C "$WT" status --porcelain)" ]]; then
  git -C "$WT" add -A
  git -C "$WT" commit -m "Commander commit $TASK_SAFE from $RUN_ID" >/dev/null
  task_branch_had_work=true
  echo "committed_worktree: $BRANCH"
fi

# Local integration only. This changes the repository branch.
if git -C "$REPO" show-ref --verify --quiet "refs/heads/$INTEGRATION"; then
  git -C "$REPO" switch "$INTEGRATION"
else
  git -C "$REPO" switch -c "$INTEGRATION" "$BASE"
fi

set +e
MERGE_OUT="$(git -C "$REPO" merge --no-ff "$BRANCH" -m "Merge $TASK_SAFE from $RUN_ID" 2>&1)"
MERGE_RC=$?
set -e
echo "$MERGE_OUT" | sed 's/^/  /'
if [[ $MERGE_RC -ne 0 ]]; then
  git -C "$REPO" merge --abort 2>/dev/null || true
  update_task_state "$TASK_SAFE" "blocked_failed_check" "merge conflict"
  echo "decision: MERGE_CONFLICT"
  echo "reason: merge of $BRANCH into $INTEGRATION conflicts; resolve manually"
  exit 1
fi
if grep -q "Already up to date" <<<"$MERGE_OUT"; then
  update_task_state "$TASK_SAFE" "merged_local" "no-op merge; already up to date"
  echo "decision: NOOP"
  echo "reason: no changes on $BRANCH to integrate"
else
  update_task_state "$TASK_SAFE" "merged_local" "merged into $INTEGRATION"
  echo "decision: MERGED_LOCAL"
fi
