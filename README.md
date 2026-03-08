# TruthGuard

**Catches false claims from AI coding agents.** Verifies that actions were actually performed — not just claimed.

<!-- TODO: Add demo GIF here -->
<!-- ![TruthGuard Demo](docs/demo.gif) -->

## The Problem

AI coding agents (Claude Code, Gemini CLI, Cursor, etc.) sometimes:

- Claim tests passed when they actually failed
- Report files were modified when nothing changed
- Skip pre-commit hooks with `--no-verify`
- Run destructive commands without warning (`rm -rf`, `git reset --hard`, `git push --force`)

These aren't malicious — they're hallucinations and shortcuts. But in a professional workflow, **unverified claims are dangerous.**

## How It Works

TruthGuard installs as a set of hooks that intercept tool calls in real-time:

| Hook | What it catches |
|------|----------------|
| **Exit Code Verifier** | Command failed (exit code ≠ 0) but agent claims success |
| **File Change Detector** | Agent claims file was edited, but checksum is unchanged |
| **Dangerous Command Blocker** | `--no-verify`, `--force push`, `rm -rf /`, `reset --hard` |
| **Test Runner** | Auto-detects project type and runs real tests |

```
PreToolUse (Bash)     → block dangerous commands before execution
PreToolUse (Write/Edit) → record file checksum before change
PostToolUse (Bash)    → verify exit code, catch test failures
PostToolUse (Write/Edit) → compare checksums, detect phantom edits
```

## Supported Agents

| Agent | Status | Integration |
|-------|--------|-------------|
| Claude Code | ✅ Ready | Native hooks |
| Gemini CLI | 🔜 Planned | MCP server |

## Quick Start

### Claude Code

1. Clone the repository:
```bash
git clone https://github.com/spyrae/truthguard.git ~/.truthguard
```

2. Add hooks to your project's `.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "~/.truthguard/scripts/block-dangerous.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "~/.truthguard/scripts/pre-file-change.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "~/.truthguard/scripts/check-exit-code.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "~/.truthguard/scripts/check-file-change.sh" }]
      }
    ]
  }
}
```

3. Done. TruthGuard now monitors every tool call.

### Slash Commands

TruthGuard includes two built-in commands:

- `/verify` — Run real tests, type checks, and linting for the current project
- `/truthguard-status` — Show session statistics (blocked commands, warnings)

## What You'll See

When TruthGuard catches something:

```
🛑 TruthGuard: Blocked git commit --no-verify. Skipping hooks defeats verification.
```

```
⚠️ TruthGuard: Command exited with code 1 and output contains test failures. Do NOT claim tests passed.
```

```
⚠️ TruthGuard: File 'utils.dart' was not actually modified. Checksum unchanged.
```

## Project Structure

```
truthguard/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── hooks/
│   └── hooks.json         # Hook configuration
├── scripts/
│   ├── block-dangerous.sh # PreToolUse: block risky commands
│   ├── pre-file-change.sh # PreToolUse: record file checksums
│   ├── check-exit-code.sh # PostToolUse: verify command results
│   ├── check-file-change.sh # PostToolUse: detect phantom edits
│   └── run-tests.sh       # Auto-detect and run project tests
├── skills/
│   ├── verify/SKILL.md    # /verify slash command
│   └── status/SKILL.md    # /truthguard-status slash command
├── LICENSE                 # BSL-1.1 (converts to MIT in 2030)
└── README.md
```

## License

[Business Source License 1.1](LICENSE) — free for all use except building competing AI verification products. Converts to MIT on 2030-03-08.

## Author

**Roman Belov** — [roman@journeybay.co](mailto:roman@journeybay.co)
