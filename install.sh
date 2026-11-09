#!/usr/bin/env bash
# Skill-only install (no plugin system): copies the skill into ~/.claude/skills.
# Usage: curl -fsSL https://raw.githubusercontent.com/daveenDev/preflight/main/install.sh | bash
set -e
T=$(mktemp -d)
git clone --depth=1 https://github.com/daveenDev/preflight "$T" >/dev/null 2>&1
mkdir -p ~/.claude/skills
rm -rf ~/.claude/skills/preflight
cp -r "$T/plugins/preflight/skills/preflight" ~/.claude/skills/preflight
rm -rf "$T"
echo "Installed preflight skill to ~/.claude/skills/preflight"
echo "For the push/merge gate, install the plugin instead (see README)."
