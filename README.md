# ✈️ Preflight

**A free AI code reviewer for [Claude Code](https://claude.com/claude-code) that checks your code before it ships.**

Linters catch style. Preflight catches the things that actually hurt in production: security holes, broken business rules, unhandled edge cases, N+1 queries, slow code, and shaky architecture. It can also act as a gate, so `git push` and `git merge` are blocked until the review passes, either on your machine or on GitHub as a [required check before merge](#github-merge-gate).

## What it checks

| Area | Examples |
|---|---|
| 🔐 **Security** | SQL/NoSQL injection, command injection, XSS, SSRF, path traversal, missing auth, IDOR, leaked secrets, vulnerable dependencies, missing security headers |
| 💼 **Business logic** | Totals that don't add up, invalid status changes, wrong role permissions, money rounding, time zone rules, non-idempotent payments and webhooks |
| 🧩 **Edge cases** | Empty/null input, duplicates, expired sessions, double clicks, date boundaries, partial failures, pagination limits |
| ⚡ **Performance** | N+1 queries (including the hidden ones), missing indexes, request waterfalls, unnecessary re-renders, oversized client bundles, O(n²) loops, memory leaks |
| 🏗️ **Architecture** | Separation of concerns, coupling, data model fit, failure handling, testability |
| 🧹 **Maintainability** | Misleading names, dead code, `any` types (kept short, last priority) |

Extra checks for **React, Next.js, Supabase/Postgres, and Firebase (Web + Android)**: Server Actions, RLS policies, `SECURITY DEFINER` functions, Firestore/Storage rules, Admin SDK, Android exported components, local SQLite injection, and more.

## What you get back

1. **Verdict:** ✅ Approve / 🟡 Approve with changes / 🔴 Request changes
2. **Scorecard:** each area rated Good / Needs work / Critical issues
3. **Top priorities:** the 3–5 fixes to do first
4. **Detailed findings:** severity, file and line, what breaks, why it matters, and a code fix
5. **Wrap-up:** unhandled edge cases, tests to add, and next steps

## Install

Preflight installs straight from GitHub: [DaveenDev/Preflight-AI-Code-Reviewer-Skill](https://github.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill).

### Option 1: Plugin (recommended, includes the push/merge gate)

In Claude Code:

```
/plugin marketplace add DaveenDev/Preflight-AI-Code-Reviewer-Skill
/plugin install preflight@daveendev
```

The first command adds this repo as a plugin marketplace (named `daveendev`). The second installs the `preflight` plugin from it. Restart Claude Code if the `/preflight:preflight` command doesn't show up right away.

You can also use the full URL: `/plugin marketplace add https://github.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill.git`

**Updating:** `/plugin marketplace update daveendev`

**Removing:** `/plugin uninstall preflight@daveendev`

### Option 2: Skill only (no gate)

macOS, Linux, or Git Bash/WSL on Windows:

```bash
curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/main/install.sh | bash
```

Or install it by hand:

```bash
git clone --depth=1 https://github.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill.git
mkdir -p ~/.claude/skills
cp -r Preflight-AI-Code-Reviewer-Skill/plugins/preflight/skills/preflight ~/.claude/skills/preflight
```

On Windows PowerShell (no bash needed):

```powershell
git clone --depth=1 https://github.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill.git $env:TEMP\preflight
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse -Force "$env:TEMP\preflight\plugins\preflight\skills\preflight" "$HOME\.claude\skills\preflight"
Remove-Item -Recurse -Force "$env:TEMP\preflight"
```

To install it for a single project, copy the folder to `.claude/skills/preflight` in that project instead.

To update, run the installer again. To remove it, delete `~/.claude/skills/preflight`.

### Check that it worked

Start a new Claude Code session and ask it to `review my changes`, or run `/preflight:preflight` (plugin) or `/preflight` (skill only). With the plugin, `/plugin` should also list `preflight` as installed.

### Troubleshooting

- **"Repository not found", or a repo called `daveenDev/preflight` doesn't exist:** that's an old address from an early draft of this README. The only repo is `DaveenDev/Preflight-AI-Code-Reviewer-Skill`. Use the commands on this page, copied from the current README on GitHub.
- **`/plugin install preflight@daveendev` says the marketplace isn't found:** run the `/plugin marketplace add` line first. The `daveendev` part is the marketplace name from `.claude-plugin/marketplace.json`, not a GitHub address.
- **The `/preflight:preflight` command doesn't show up:** restart Claude Code. If you installed only the skill, use `/preflight` instead.
- **The `curl ... | bash` command fails on Windows:** use the PowerShell commands above, or run the command in Git Bash or WSL.
- **The push/merge gate says `jq not installed, skipping`:** install [jq](https://jqlang.org) to turn the gate on. It's skipped, not broken, without it.

## Usage

Ask Claude Code to review something:

```
review my changes
review src/app/api/orders/route.ts
review PR #42
```

Or call it directly with `/preflight:preflight` (plugin) or `/preflight` (skill only).

## The push/merge gate

With the plugin installed, when Claude Code tries to run `git push`, `git merge`, or `gh pr merge`:

1. The command is blocked until the exact commit being shipped has passed review.
2. Claude reviews the diff and ends with `REVIEW_RESULT: PASS` or `REVIEW_RESULT: FAIL`.
3. **Any Critical or High finding fails.** Claude shows the findings and offers to fix them. Medium and Low findings are reported but don't block.
4. On PASS, the push or merge goes ahead. Every new commit needs a new review.

Requires `jq` (and `gh` for PR merges).

**Turning it off:**
- For one repo: create `.claude/preflight-off`
- For one session: `export PREFLIGHT=off`

### Also gate pushes from your terminal (optional)

The plugin gate covers pushes that Claude Code runs. To review pushes you make yourself (terminal, VS Code, any Git client), add the Git hook:

```bash
curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/main/extras/pre-push -o .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

It runs the review with `claude -p` before every push. To skip it once, run `git push --no-verify`.

## GitHub merge gate

The gates above run on a machine. The GitHub merge gate runs on GitHub itself, so it doesn't matter where a merge comes from: a local Claude Code session, a cloud session, `gh pr merge`, or someone clicking **Merge** in the browser. Every pull request gets a Preflight review, and GitHub won't merge it until the review passes.

How it works:

1. When a PR is opened, updated, or marked ready for review, a GitHub Actions workflow runs Preflight through the official [Claude Code GitHub Action](https://github.com/anthropics/claude-code-action).
2. Claude posts the full report as a PR comment, plus an inline comment on each Critical or High finding.
3. The **Preflight review** check fails on any Critical or High finding. Medium and Low findings are reported but don't block. If the review can't finish, the check fails too, so nothing slips through.
4. A branch ruleset makes that check required. Every new push re-runs the review.

### Quick setup (one command)

From inside the repo you want to gate, with the [GitHub CLI](https://cli.github.com) (`gh`) installed and logged in as a repo admin:

```bash
curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/main/extras/setup-github-gate.sh | bash
```

Or, with the plugin installed, run this in Claude Code:

```
/preflight:setup-github
```

Either one:

1. **Opens a PR** that adds `.github/workflows/preflight.yml`. It's made in a separate worktree, so your current branch and uncommitted changes aren't touched.
2. **Stores your Claude secret.** The script asks for it with hidden input. The slash command never handles your key: it tells you to run `gh secret set` in your own terminal, or `/install-github-app`.
3. **Creates a branch ruleset** named "Preflight merge gate" on your default branch: pull requests required, and the Preflight check must pass.

It asks before each step and skips anything already set up, so it's safe to run again. You still need to install the [Claude GitHub app](https://github.com/apps/claude) on the repo yourself if `/install-github-app` hasn't done it. The setup PR is the first test of the gate: merge it once its check passes.

Script options (pass them after `bash -s --`, for example `| bash -s -- --dry-run`):

| Option | What it does |
|---|---|
| `--dry-run` | Shows what would change, and changes nothing |
| `--yes` | Doesn't ask before each step |
| `--no-pr` | Writes the workflow into your checkout instead of opening a PR |
| `--no-workflow`, `--no-secret`, `--no-ruleset` | Skips that step |
| `--ref <tag>` | Pins the gate to a Preflight tag or commit instead of `main` |

### Set it up by hand

**1. Add the workflow.** Copy [`extras/github/preflight.yml`](extras/github/preflight.yml) to `.github/workflows/preflight.yml` in the repo you want to gate:

```bash
mkdir -p .github/workflows
curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/main/extras/github/preflight.yml -o .github/workflows/preflight.yml
```

It's a short file that calls the shared workflow in this repo, so improvements to Preflight reach every gated repo automatically. To freeze a version instead, change `@main` to a tag or commit SHA.

**2. Connect Claude.** The quickest way is to run this in Claude Code from inside the repo:

```
/install-github-app
```

It installs the [Claude GitHub app](https://github.com/apps/claude) and adds the secret for you. To do it by hand, install the app, then add one repo secret under **Settings → Secrets and variables → Actions**:

| Secret | Billed to |
|---|---|
| `ANTHROPIC_API_KEY` | Your Anthropic API account ([console.anthropic.com](https://console.anthropic.com)) |
| `CLAUDE_CODE_OAUTH_TOKEN` | Your Claude Pro/Max plan. Create it with `claude setup-token` |

**3. Make the check required.** In the repo, go to **Settings → Rules → Rulesets → New branch ruleset**:

- **Target branches:** your default branch (for example `main`)
- Turn on **Require a pull request before merging**, so nobody can push straight to `main`
- Turn on **Require status checks to pass**, and add `preflight / Preflight review`. The check only shows up in the search box after the workflow has run once, so open a test PR first.
- Leave the **Bypass list** empty if you want the gate to apply to admins too.

**4. Open a pull request** and watch the **Preflight review** check run.

### Options

Set these under `with:` in your copy of `preflight.yml`:

| Input | What it does |
|---|---|
| `model` | Claude model to review with, for example `claude-opus-5-5`. Leave it out to use the Claude Code default. |
| `extra_instructions` | Business rules or focus areas for this repo, added to the review prompt |
| `timeout_minutes` | Longest a review may run (default 30) |
| `marketplace_url` | Load Preflight from your own fork instead of this repo |

### Good to know

- **One file per repo:** a personal GitHub account can't apply a rule to all its repos at once, so add the workflow and ruleset to each repo you want gated. In a GitHub organization, an org-level ruleset can require the workflow across many repos.
- **Pull requests from forks:** GitHub doesn't give forks your secrets, so those PRs fail the check and need a maintainer to review them.
- **Draft pull requests:** these are skipped until they're marked ready for review.
- **Cost:** each review uses GitHub Actions minutes plus Claude usage on the account behind your secret.
- **Prompt injection:** Claude only gets read-only tools plus PR comments, and it's told to treat the PR as data. AI review can still be fooled, though, so keep human review on critical code.
- The local plugin gate and pre-push hook still give faster feedback. The GitHub check is the one that can't be skipped.

## Repo layout

```
.claude-plugin/marketplace.json        # marketplace listing
.github/workflows/preflight-review.yml # shared GitHub merge gate workflow
.github/workflows/preflight.yml        # runs the gate on this repo's own PRs
extras/github/preflight.yml            # copy into other repos to gate them
extras/setup-github-gate.sh            # one-command GitHub gate setup
plugins/preflight/
  .claude-plugin/plugin.json           # plugin manifest
  skills/preflight/SKILL.md            # the review instructions
  commands/setup-github.md             # /preflight:setup-github
  hooks/hooks.json                     # PreToolUse hook config
  hooks/review-gate.sh                 # push/merge gate
extras/pre-push                        # optional Git hook
install.sh                             # skill-only installer
```

## Notes

- Preflight is an AI review. It catches a lot, but it doesn't replace tests, a security audit, or a human reviewer on critical code.
- Reviews run on your own Claude Code account and usage. Preflight itself has no server and collects nothing.

## Contributing

[Issues](https://github.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/issues) and [pull requests](https://github.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/pulls) are welcome, especially new stack-specific checks (Laravel, Django, Rails, Go, and others).

## License

MIT © Ruben B. Duran ([@DaveenDev](https://github.com/DaveenDev))
