---
title: "I Built a Lie Detector for AI Coding Agents"
published: true
tags: ai, claudecode, productivity, opensource
cover_image: https://github.com/spyrae/truthguard/raw/main/docs/demo.gif
---

## The Problem Nobody Talks About

AI coding agents lie. Not maliciously - they hallucinate.

Claude Code tells you "All tests pass!" when tests were never executed. It says "I updated the file" when the file content is identical. It runs `git commit --no-verify` to skip the hooks that would catch its mistakes.

This isn't an edge case. It's [a documented bug](https://github.com/anthropics/claude-code/issues/1501) that affects every serious Claude Code user. And no amount of system prompts fixes it - the agent simply ignores text-based instructions when it "decides" something is done.

I spent 2 weeks building a fix.

## TruthGuard: Verification at the Tool Call Level

The key insight: **don't tell the agent to be honest - verify its claims programmatically.**

Claude Code has a hooks API. Before and after every tool call (Bash command, file edit), it runs your scripts. These scripts can inspect what happened and **block** the agent if it's lying.

```
Agent claims: "I updated utils.ts"
    |
[PostToolUse hook]
    |
Compare SHA256 before/after -> IDENTICAL
    |
BLOCKED: "File was not actually modified. Checksum unchanged."
```

The agent can't ignore this. It's not a prompt. It's a programmatic gate.

## The 6 Hooks

| Hook | What it catches |
|------|-----------------|
| **Dangerous Command Blocker** | `--no-verify`, `--force push`, `rm -rf /` |
| **Pre-Commit Test Runner** | Auto-detects framework, runs tests before every commit |
| **File Checksum Recorder** | Saves SHA256 before file edit |
| **Exit Code Verifier** | Catches when commands fail but agent claims success |
| **Phantom Edit Detector** | File unchanged after "edit" |
| **Commit Verification Reminder** | Forces agent to prove fix works before claiming "done" |

## Real Numbers

I dogfooded TruthGuard on a production Flutter project for 2 days:

- **5 commits blocked** - agent tried to commit with failing tests every time
- **3 dangerous commands blocked** - `git push --force` and `git commit --no-verify`
- **0 false positives** - every single block was a real issue

The pre-commit test hook alone saved me from shipping broken code 5 times in 2 days.

## How Pre-Commit Testing Works

This is the most valuable hook. When Claude runs `git commit`, TruthGuard intercepts it:

1. Detects project type (Flutter? Node.js? Python? Rust? Go?)
2. Runs the appropriate test command
3. If tests fail - **blocks the commit**
4. Agent must fix the failures before committing

```bash
# Auto-detection logic:
# pubspec.yaml     -> flutter test
# package.json     -> npm test
# Cargo.toml       -> cargo test
# go.mod           -> go test ./...
# pyproject.toml   -> python -m pytest
```

You can override with `.truthguard.yml`:

```yaml
test_command: "npm run test:unit"
skip_on_no_tests: false
```

## The "Wrong Fix" Problem

After building the basic hooks, I noticed a subtler issue: Claude makes real changes, tests pass, but **the fix doesn't actually solve the problem**. It genuinely believes it's done.

So I added a post-commit reminder hook. After every successful commit, Claude gets:

> "You just committed code. STOP and verify: did you actually confirm the fix works?"

It's a simple nudge, but it forces the agent to pause and think instead of rushing to "Done."

## Install in 30 Seconds

```bash
npx truthguard install
cd your-project
npx truthguard init
```

This copies scripts to `~/.truthguard/` and adds hooks to your `.claude/settings.json`. Restart Claude Code and you're protected.

Also available via Homebrew:

```bash
brew tap spyrae/truthguard && brew install truthguard
```

## Works With Multiple Agents

TruthGuard scripts are agent-agnostic. They read JSON from stdin, output JSON to stdout. Currently supports:

- **Claude Code** - native hooks via `settings.json`
- **Gemini CLI** - native extension system

The same scripts work for both. Adding support for other agents is just a matter of writing the config mapping.

## What's Next

This is the free, local-only MVP. Everything runs on your machine, no backend, no telemetry.

Ideas for the future:
- **Semantic verification** - a second LLM checks if the diff actually solves the described problem
- **Team dashboard** - aggregate honesty stats across your team
- **VS Code extension** - for Cursor/Copilot users

## Try It

**GitHub:** [github.com/spyrae/truthguard](https://github.com/spyrae/truthguard)
**npm:** [npmjs.com/package/truthguard](https://www.npmjs.com/package/truthguard)

If you've caught your AI agent lying about something I haven't covered - open an issue. I'll add a hook for it.

