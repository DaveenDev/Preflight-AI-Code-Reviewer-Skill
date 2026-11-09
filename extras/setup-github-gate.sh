#!/usr/bin/env bash
# Sets up the Preflight GitHub merge gate for the repo you run it in:
#   1. Opens a PR that adds .github/workflows/preflight.yml
#   2. Stores a Claude secret (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
#   3. Creates a branch ruleset: PRs required, Preflight check required
# It asks before each step and skips anything that's already set up.
#
# Needs: git, curl, and the GitHub CLI (gh) logged in with admin access to the repo.
#
# Run it from inside your repo:
#   curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/main/extras/setup-github-gate.sh | bash
# Pass options after "bash -s --", for example:
#   curl -fsSL .../setup-github-gate.sh | bash -s -- --dry-run

set -euo pipefail

SOURCE_REPO="DaveenDev/Preflight-AI-Code-Reviewer-Skill"
REF="main"
CHECK_NAME="preflight / Preflight review"
RULESET_NAME="Preflight merge gate"
WORKFLOW=".github/workflows/preflight.yml"
BRANCH="preflight/setup-merge-gate"

YES=0 DRY=0 DO_WORKFLOW=1 DO_SECRET=1 DO_RULESET=1 USE_PR=1

usage() {
  cat <<'EOF'
Usage: setup-github-gate.sh [options]

  --yes          Don't ask before each step (the secret step still needs you)
  --dry-run      Show what would change, but change nothing
  --no-workflow  Skip adding the workflow
  --no-secret    Skip the secret step (set it yourself later)
  --no-ruleset   Skip creating the branch ruleset
  --no-pr        Write the workflow into this checkout instead of opening a PR
  --ref <ref>    Preflight version to use, a branch, tag, or commit (default: main)
  -h, --help     Show this help
EOF
}

say()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)      YES=1 ;;
    --dry-run)     DRY=1 ;;
    --no-workflow) DO_WORKFLOW=0 ;;
    --no-secret)   DO_SECRET=0 ;;
    --no-ruleset)  DO_RULESET=0 ;;
    --no-pr)       USE_PR=0 ;;
    --ref)         [ $# -ge 2 ] || die "--ref needs a value"; REF="$2"; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             usage >&2; die "Unknown option: $1" ;;
  esac
  shift
done

# Questions go to the terminal, so this also works under "curl ... | bash".
TTY=""
if { : </dev/tty; } 2>/dev/null; then TTY=/dev/tty; fi

ask() {
  [ "$YES" = 1 ] && return 0
  [ -n "$TTY" ] || die "No terminal to ask on. Re-run with --yes to accept every step."
  local answer
  printf '%s [Y/n] ' "$1" >"$TTY"
  read -r answer <"$TTY" || answer=n
  case "$answer" in ""|y|Y|yes|Yes|YES) return 0 ;; *) return 1 ;; esac
}

# ---- Checks -----------------------------------------------------------------

for c in git gh curl; do
  command -v "$c" >/dev/null 2>&1 || die "$c is not installed."
done

top=$(git rev-parse --show-toplevel 2>/dev/null) || die "Run this from inside a Git repository."
cd "$top"
git remote get-url origin >/dev/null 2>&1 || die "This repo has no 'origin' remote on GitHub."
gh auth status >/dev/null 2>&1 || die "The GitHub CLI isn't logged in. Run: gh auth login"

info=$(gh repo view --json nameWithOwner,defaultBranchRef,viewerPermission \
  -q '[.nameWithOwner, .defaultBranchRef.name, .viewerPermission] | @tsv' 2>/dev/null) \
  || die "Couldn't find this repo on GitHub. Check that 'origin' points to GitHub."
IFS=$'\t' read -r REPO DEFAULT PERM <<<"$info"

say "Repo:           $REPO"
say "Default branch: $DEFAULT"
say "Your access:    $PERM"
[ "$DRY" = 1 ] && say "Dry run: nothing will be changed."

if [ "$PERM" != "ADMIN" ]; then
  warn "You need admin access to add secrets and rulesets. Those steps will be skipped; ask a repo admin to finish them."
  DO_SECRET=0
  DO_RULESET=0
fi

WORKFLOW_URL="https://raw.githubusercontent.com/$SOURCE_REPO/$REF/extras/github/preflight.yml"

tmp=$(mktemp -d)
worktree=""
cleanup() {
  if [ -n "$worktree" ] && [ -d "$worktree" ]; then
    git worktree remove --force "$worktree" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

download_workflow() {
  curl -fsSL "$WORKFLOW_URL" -o "$tmp/preflight.yml" || die "Couldn't download $WORKFLOW_URL"
  if [ "$REF" != "main" ]; then
    sed "s#preflight-review.yml@main#preflight-review.yml@$REF#" "$tmp/preflight.yml" >"$tmp/preflight.pinned.yml"
    mv "$tmp/preflight.pinned.yml" "$tmp/preflight.yml"
  fi
}

STATUS_WORKFLOW="skipped"
STATUS_SECRET="skipped"
STATUS_RULESET="skipped"
PR_URL=""

# ---- 1. Workflow -------------------------------------------------------------

if [ "$DO_WORKFLOW" = 1 ]; then
  step "1. Add the Preflight workflow ($WORKFLOW)"

  open_pr=$(gh pr list --repo "$REPO" --state open --search "head:$BRANCH" --json url -q '.[0].url' 2>/dev/null || true)

  if gh api "repos/$REPO/contents/$WORKFLOW?ref=$DEFAULT" >/dev/null 2>&1; then
    say "Already on $DEFAULT. Skipping."
    STATUS_WORKFLOW="already set up"
  elif [ -n "$open_pr" ]; then
    say "A setup PR is already open: $open_pr"
    STATUS_WORKFLOW="PR already open"
    PR_URL="$open_pr"
  elif [ "$USE_PR" = 0 ]; then
    if [ -f "$WORKFLOW" ]; then
      say "$WORKFLOW already exists in this checkout. Skipping."
      STATUS_WORKFLOW="already in checkout"
    elif ask "Write $WORKFLOW into this checkout?"; then
      if [ "$DRY" = 1 ]; then
        say "(dry run) Would download $WORKFLOW_URL to $WORKFLOW"
      else
        download_workflow
        mkdir -p .github/workflows
        cp "$tmp/preflight.yml" "$WORKFLOW"
        say "Wrote $WORKFLOW. Commit it and open a PR to $DEFAULT."
      fi
      STATUS_WORKFLOW="written to checkout (not committed)"
    fi
  elif ask "Open a PR that adds $WORKFLOW to $DEFAULT?"; then
    # Pick a branch name that isn't taken, locally or on GitHub.
    if git show-ref --verify --quiet "refs/heads/$BRANCH" \
      || git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
      BRANCH="$BRANCH-$(date +%Y%m%d%H%M%S)"
    fi

    if [ "$DRY" = 1 ]; then
      say "(dry run) Would create branch $BRANCH from origin/$DEFAULT, commit $WORKFLOW,"
      say "          push it, and open a PR to $DEFAULT. Your checkout isn't touched."
      STATUS_WORKFLOW="PR would be opened"
    else
      download_workflow
      git fetch --quiet origin "$DEFAULT"
      # Use a separate worktree so your current branch and changes aren't touched.
      worktree="$tmp/worktree"
      git worktree add --quiet -b "$BRANCH" "$worktree" "origin/$DEFAULT"
      mkdir -p "$worktree/.github/workflows"
      cp "$tmp/preflight.yml" "$worktree/$WORKFLOW"
      git -C "$worktree" add "$WORKFLOW"
      git -C "$worktree" commit --quiet -m "Add Preflight merge gate" \
        -m "Runs a Preflight AI code review on every pull request. See https://github.com/$SOURCE_REPO#github-merge-gate"
      git -C "$worktree" push --quiet -u origin "$BRANCH"
      PR_URL=$(gh pr create --repo "$REPO" --base "$DEFAULT" --head "$BRANCH" \
        --title "Add Preflight merge gate" \
        --body "This adds the [Preflight](https://github.com/$SOURCE_REPO) merge gate. Every pull request gets an AI code review, and the **$CHECK_NAME** check fails on any Critical or High finding.

This PR is the first test: the check should run on it once a Claude secret is set.")
      git worktree remove --force "$worktree" >/dev/null 2>&1 || true
      worktree=""
      git branch -D "$BRANCH" >/dev/null 2>&1 || true
      say "Opened $PR_URL"
      STATUS_WORKFLOW="PR opened"
    fi
  fi
fi

# ---- 2. Claude secret ----------------------------------------------------------

if [ "$DO_SECRET" = 1 ]; then
  step "2. Store a Claude credential as a repo secret"

  secrets=$(gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}' || true)
  if printf '%s\n' "$secrets" | grep -qxE 'ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN'; then
    say "A Claude secret is already set. Skipping."
    STATUS_SECRET="already set"
  elif [ -z "$TTY" ]; then
    say "No terminal available to type the secret into. Set it yourself later (see below)."
  else
    say "Which credential should the review use?"
    say "  1) Anthropic API key (billed to your API account)"
    say "  2) Claude Pro/Max token (create one with: claude setup-token)"
    say "  3) Skip for now"
    printf 'Choose 1, 2, or 3: ' >"$TTY"
    read -r choice <"$TTY" || choice=3
    case "$choice" in
      1) secret_name="ANTHROPIC_API_KEY" ;;
      2) secret_name="CLAUDE_CODE_OAUTH_TOKEN" ;;
      *) secret_name="" ;;
    esac
    if [ -n "$secret_name" ]; then
      if [ "$DRY" = 1 ]; then
        say "(dry run) Would run: gh secret set $secret_name --repo $REPO"
        STATUS_SECRET="would be set"
      else
        say "Paste the value when gh asks for it. It won't be shown or saved anywhere else."
        if gh secret set "$secret_name" --repo "$REPO" <"$TTY"; then
          STATUS_SECRET="$secret_name set"
        else
          warn "Couldn't set the secret. Set it later (see below)."
        fi
      fi
    fi
  fi
fi

# ---- 3. Branch ruleset ---------------------------------------------------------

if [ "$DO_RULESET" = 1 ]; then
  step "3. Require the Preflight check before merging into $DEFAULT"

  if gh api "repos/$REPO/rulesets" -q '.[].name' 2>/dev/null | grep -qxF "$RULESET_NAME"; then
    say "Ruleset \"$RULESET_NAME\" already exists. Skipping."
    STATUS_RULESET="already exists"
  elif ask "Create ruleset \"$RULESET_NAME\" (PRs required, \"$CHECK_NAME\" must pass)?"; then
    payload=$(cat <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "$CHECK_NAME" } ] } }
  ]
}
EOF
)
    if [ "$DRY" = 1 ]; then
      say "(dry run) Would POST this ruleset to repos/$REPO/rulesets:"
      say "$payload"
      STATUS_RULESET="would be created"
    elif err=$(printf '%s' "$payload" | gh api -X POST "repos/$REPO/rulesets" --input - 2>&1 >/dev/null); then
      say "Created. Nobody can merge into $DEFAULT until the check passes, admins included."
      STATUS_RULESET="created"
    else
      warn "Couldn't create the ruleset: $err"
      warn "Rulesets on private repos need GitHub Pro, Team, or Enterprise. You can add one by hand under Settings > Rules > Rulesets."
      STATUS_RULESET="failed"
    fi
  fi
fi

# ---- Summary -----------------------------------------------------------------

step "Summary for $REPO"
say "  Workflow: $STATUS_WORKFLOW${PR_URL:+ ($PR_URL)}"
say "  Secret:   $STATUS_SECRET"
say "  Ruleset:  $STATUS_RULESET"
say ""
say "Still needed if you haven't done it:"
say "  - Install the Claude GitHub app on $REPO: https://github.com/apps/claude"
if [ "$STATUS_SECRET" = "skipped" ]; then
  say "  - Add a Claude secret, from a terminal in this repo:"
  say "      gh secret set ANTHROPIC_API_KEY"
  say "    or, for a Claude Pro/Max plan: claude setup-token, then gh secret set CLAUDE_CODE_OAUTH_TOKEN"
  say "    (Running /install-github-app in Claude Code does both of these for you.)"
fi
[ -n "$PR_URL" ] && say "  - Merge the setup PR once its Preflight check passes: $PR_URL"
exit 0
