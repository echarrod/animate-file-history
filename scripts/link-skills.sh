#!/usr/bin/env bash
# Symlink every skill in this repo into ~/.claude/skills (Claude Code) and ~/.agents/skills (Codex).
# Re-run after adding a skill. Existing non-symlink paths are left alone.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)

for targets in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  mkdir -p "$targets"
  for skill in "$repo"/skills/*/; do
    name=$(basename "$skill")
    dest="$targets/$name"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "skip $dest (exists, not a symlink)" >&2
      continue
    fi
    ln -sfn "${skill%/}" "$dest"
    echo "linked $dest"
  done
done
