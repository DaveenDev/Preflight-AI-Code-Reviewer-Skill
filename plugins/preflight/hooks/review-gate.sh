#!/usr/bin/env bash
# Claude Code PreToolUse hook: blocks `git push`, `git merge` and `gh pr merge`
# until the preflight skill has passed the exact commit being shipped.
# Requires: jq (and gh for PR merges).

# Opt out: set PREFLIGHT=off, or create .claude/preflight-off in the repo.
[ "${PREFLIGHT:-on}" = "off" ] && exit 0
command -v jq >/dev/null || { echo "preflight: jq not installed, skipping" >&2; exit 0; }

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

# Only act on push/merge commands.
if ! printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])(git[[:space:]]+(push|merge)|gh[[:space:]]+pr[[:space:]]+merge)([[:space:]]|$)'; then
  exit 0
fi

# Let merge housekeeping through.
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+merge[[:space:]]+--(abort|continue|quit)'; then
  exit 0
fi

git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null)
[ -f "$top/.claude/preflight-off" ] && exit 0
passed=$(cat "$git_dir/preflight-passed" 2>/dev/null)

if printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge'; then
  pr=$(printf '%s' "$cmd" | grep -Eo 'gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+[0-9]+' | grep -Eo '[0-9]+$')
  target=$(gh pr view $pr --json headRefOid -q .headRefOid 2>/dev/null)
  what="PR ${pr:-for this branch}"
elif printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+merge'; then
  branch=$(printf '%s' "$cmd" | sed -E 's/.*git[[:space:]]+merge[[:space:]]+//' | tr ' ' '\n' | grep -v '^-' | grep -v '^$' | head -1)
  target=$(git rev-parse --verify --quiet "$branch" 2>/dev/null)
  what="branch '$branch'"
else
  target=$(git rev-parse HEAD)
  what="HEAD"
fi

if [ -n "$target" ] && [ "$target" = "$passed" ]; then
  exit 0
fi

echo "Blocked: $what has not passed Preflight code review. Use the preflight skill in pre-merge/pre-push gate mode on these changes first. Only push/merge after REVIEW_RESULT: PASS and the marker file is written." >&2
exit 2
