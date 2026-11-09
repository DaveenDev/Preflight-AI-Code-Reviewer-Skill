# ✈️ Preflight

**A free AI code reviewer for [Claude Code](https://claude.com/claude-code) that checks your code before it ships.**

Linters catch style. Preflight catches the things that actually hurt in production: security holes, broken business rules, unhandled edge cases, N+1 queries, slow code, and shaky architecture. It can also act as a gate, so `git push` and `git merge` are blocked until the review passes.

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

### Option 1: Plugin (recommended, includes the push/merge gate)

In Claude Code:

```
/plugin marketplace add daveenDev/preflight
/plugin install preflight@daveendev
```

### Option 2: Skill only (no gate)

```bash
curl -fsSL https://raw.githubusercontent.com/daveenDev/preflight/main/install.sh | bash
```

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
curl -fsSL https://raw.githubusercontent.com/daveenDev/preflight/main/extras/pre-push -o .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

It runs the review with `claude -p` before every push. To skip it once, run `git push --no-verify`.

## Repo layout

```
.claude-plugin/marketplace.json        # marketplace listing
plugins/preflight/
  .claude-plugin/plugin.json           # plugin manifest
  skills/preflight/SKILL.md            # the review instructions
  hooks/hooks.json                     # PreToolUse hook config
  hooks/review-gate.sh                 # push/merge gate
extras/pre-push                        # optional Git hook
install.sh                             # skill-only installer
```

## Notes

- Preflight is an AI review. It catches a lot, but it doesn't replace tests, a security audit, or a human reviewer on critical code.
- Reviews run on your own Claude Code account and usage. Preflight itself has no server and collects nothing.

## Contributing

Issues and PRs are welcome, especially new stack-specific checks (Laravel, Django, Rails, Go, and others).

## License

MIT © Ruben B. Duran ([@daveenDev](https://github.com/daveenDev))
