---
description: Set up the Preflight GitHub merge gate in this repo (workflow PR, required-check ruleset, Claude secret instructions).
argument-hint: "[--dry-run] [--no-ruleset] [--no-pr] [--ref <tag>]"
allowed-tools: Bash(git rev-parse:*), Bash(git remote:*), Bash(gh auth status:*), Bash(gh repo view:*), Bash(gh secret list:*), Bash(mktemp:*), Bash(curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/:*), Bash(bash:*)
---

Set up the Preflight GitHub merge gate for the repository in the current directory. When it's done, every pull request into the default branch gets a Preflight review, and GitHub blocks the merge until the "preflight / Preflight review" check passes.

Arguments from the user, passed to the setup script: `$ARGUMENTS`

## Steps

1. **Check what's needed.** Confirm you're inside a Git repo (`git rev-parse --show-toplevel`), that `gh` is installed and logged in (`gh auth status`), and read the repo name, default branch, and access level with `gh repo view --json nameWithOwner,defaultBranchRef,viewerPermission`. If `gh` is missing or logged out, tell the user how to fix it (`gh auth login`) and stop.

2. **Say what will change and ask once.** In two or three lines, tell the user what the script will do on GitHub for that repo:
   - Open a pull request that adds `.github/workflows/preflight.yml`. Their current branch and uncommitted changes aren't touched.
   - Create a branch ruleset named "Preflight merge gate" on the default branch: pull requests required, and the Preflight check must pass. It applies to admins too.
   Skip any item the user turned off with an argument, and say if `--dry-run` was given. Wait for a yes before going on.

3. **Run the setup script.** Download it to a temp folder, then run it with `--yes --no-secret` plus the user's arguments:

   ```bash
   tmp=$(mktemp -d)
   curl -fsSL https://raw.githubusercontent.com/DaveenDev/Preflight-AI-Code-Reviewer-Skill/main/extras/setup-github-gate.sh -o "$tmp/setup-github-gate.sh"
   bash "$tmp/setup-github-gate.sh" --yes --no-secret $ARGUMENTS
   ```

   The script skips anything that's already set up, so it's safe to run again.

4. **Never handle the Claude credential yourself.** Don't ask the user to paste an API key or token into the chat, and don't run `gh secret set` with a value. Check whether a secret already exists with `gh secret list`. If neither `ANTHROPIC_API_KEY` nor `CLAUDE_CODE_OAUTH_TOKEN` is set, tell the user to do one of these themselves:
   - Run `/install-github-app` in Claude Code, which installs the Claude GitHub app and stores the secret.
   - Or, in their own terminal from the repo: `gh secret set ANTHROPIC_API_KEY` (it asks for the value with hidden input). For a Claude Pro/Max plan, run `claude setup-token` first and use `gh secret set CLAUDE_CODE_OAUTH_TOKEN` instead.

5. **Report the result.** Give the setup PR link, whether the ruleset was created, and what's still left: the Claude GitHub app (https://github.com/apps/claude) if it isn't installed, and the secret if it's missing. Explain that the setup PR is the first test: its Preflight check runs once the secret is in place, and it can be merged when the check passes.

## If something fails

- **Not admin:** the secret and ruleset steps need admin access. Say which steps a repo admin still has to do.
- **Ruleset refused on a private repo:** rulesets on private repos need GitHub Pro, Team, or Enterprise. The workflow still runs and comments on PRs, but GitHub won't block the merge until there's a ruleset or branch protection rule.
- **Push rejected:** the repo may already block pushing new branches, or the user may lack write access. Show the error and suggest `--no-pr`, which writes the workflow into the current checkout so they can commit it themselves.
