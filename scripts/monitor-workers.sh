#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="${CLAUDE_COMMANDER_SKILL_DIR:-$HOME/.claude/skills/claude-commander}"
exec "$SKILL_DIR/scripts/commander.sh" monitor "$@"
