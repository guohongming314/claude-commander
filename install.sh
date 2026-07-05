#!/usr/bin/env bash
# Install claude-commander as a user-scope Claude Code skill by symlinking
# this repo into ~/.claude/skills/. The repo stays the single source of truth,
# so `git pull` here updates the live skill.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/skills/claude-commander"

mkdir -p "$HOME/.claude/skills"

if [ -L "$DEST" ]; then
  echo "Replacing existing symlink at $DEST"
  rm "$DEST"
elif [ -e "$DEST" ]; then
  backup="$DEST.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing $DEST -> $backup"
  mv "$DEST" "$backup"
fi

ln -s "$REPO_DIR" "$DEST"
echo "Linked $DEST -> $REPO_DIR"
echo "Done. Invoke the skill in Claude Code with /claude-commander."
