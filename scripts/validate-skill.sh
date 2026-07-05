#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="${CLAUDE_COMMANDER_SKILL_DIR:-$HOME/.claude/skills/claude-commander}"

required_files=(
  "SKILL.md"
  "references/safety-boundaries.md"
  "references/worktree-protocol.md"
  "references/loop-protocol.md"
  "references/reference-first-learning.md"
  "references/agent-budget-policy.md"
  "references/ai-tool-orchestrator-patterns.md"
  "references/runtime-adapters.md"
  "templates/goal-contract.md"
  "templates/commander-spec.md"
  "templates/task-dag.json"
  "templates/worker-task.md"
  "templates/reviewer-task.md"
  "templates/revision-task.md"
  "templates/final-report.md"
  "scripts/commander.sh"
  "scripts/launch-worker.sh"
  "scripts/review-worker.sh"
  "scripts/gate-merge.sh"
  "scripts/cleanup-worktrees.sh"
)

for rel in "${required_files[@]}"; do
  if [[ ! -f "$SKILL_DIR/$rel" ]]; then
    echo "MISSING: $rel" >&2
    exit 1
  fi
done

for script in "$SKILL_DIR"/scripts/*.sh; do
  bash -n "$script"
done

python3 - "$SKILL_DIR/templates/task-dag.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
assert isinstance(data.get('tasks'), list), 'task-dag template must contain tasks list'
assert isinstance(data.get('budgets'), dict), 'task-dag template must contain budgets'
required_states = {'planned','ready','running','succeeded_unreviewed','review_passed','merged_local','failed_abort'}
assert required_states.issubset(set(data.get('states', []))), 'task-dag missing required lifecycle states'
assert data['budgets'].get('max_concurrent_total', 999) <= 3, 'default max_concurrent_total must stay conservative'
PY

for needle in \
  "Goal-only orchestration" \
  "Reference-first learning" \
  "Agent budget and fan-out control" \
  "agent-budget-policy.md" \
  "file/path claims" \
  "runtime-adapters.md"; do
  if ! grep -q "$needle" "$SKILL_DIR/SKILL.md"; then
    echo "SKILL.md missing required phrase: $needle" >&2
    exit 1
  fi
done

echo "claude-commander skill validation passed"
