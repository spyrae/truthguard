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
| **Pre-Commit Test Runner** | Auto-detects project type and runs tests before every commit |

## Supported Agents

| Agent | Status | Integration |
|-------|--------|-------------|
| Claude Code | ✅ Ready | Native hooks via `.claude/settings.json` |
| Gemini CLI | ✅ Ready | Native extension via `gemini extensions install` |

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
        "hooks": [
          { "type": "command", "command": "~/.truthguard/scripts/block-dangerous.sh" },
          { "type": "command", "command": "~/.truthguard/scripts/pre-commit-tests.sh", "timeout": 120 }
        ]
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

### Gemini CLI

```bash
gemini extensions install https://github.com/spyrae/truthguard
```

That's it. TruthGuard hooks are loaded automatically via the extension system.

### Slash Commands

TruthGuard includes two built-in commands (Claude Code):

- `/verify` — Run real tests, type checks, and linting for the current project
- `/truthguard-status` — Show session statistics (blocked commands, warnings)

### Configuration

Create `.truthguard.yml` in your project root to customize:

```yaml
# Override auto-detected test command
test_command: "npm run test:unit"

# Block commit if no tests found (default: true = allow)
skip_on_no_tests: false
```

## What You'll See

When TruthGuard catches something:

```
🛑 TruthGuard: Blocked git commit --no-verify. Skipping hooks defeats verification.
```

```
🛑 TruthGuard: Test failures detected (exit code 1). Agent must fix before continuing.
```

```
⚠️ TruthGuard: File 'utils.dart' was not actually modified. Checksum unchanged.
```

```
🛑 TruthGuard: Build failure detected (exit code 1).
```

## Project Structure

```
truthguard/
├── .claude-plugin/
│   └── plugin.json           # Claude Code plugin manifest
├── gemini-extension.json     # Gemini CLI extension manifest
├── GEMINI.md                 # Context injected into Gemini CLI
├── hooks/
│   ├── hooks.json            # Claude Code hook configuration
│   └── gemini.json           # Gemini CLI hook configuration
├── scripts/
│   ├── block-dangerous.sh    # Block risky git commands
│   ├── pre-commit-tests.sh   # Run tests before git commit
│   ├── pre-file-change.sh    # Record file checksums
│   ├── check-exit-code.sh    # Verify command exit codes
│   ├── check-file-change.sh  # Detect phantom edits
│   └── run-tests.sh          # Auto-detect and run project tests
├── skills/
│   ├── verify/SKILL.md       # /verify slash command
│   └── status/SKILL.md       # /truthguard-status slash command
├── LICENSE                    # BSL-1.1 (converts to MIT in 2030)
└── README.md
```

## How Hooks Map Between Agents

| Claude Code | Gemini CLI | Script |
|-------------|------------|--------|
| PreToolUse → Bash | BeforeTool → run_shell_command | `block-dangerous.sh`, `pre-commit-tests.sh` |
| PreToolUse → Write\|Edit | BeforeTool → write_file\|replace | `pre-file-change.sh` |
| PostToolUse → Bash | AfterTool → run_shell_command | `check-exit-code.sh` |
| PostToolUse → Write\|Edit | AfterTool → write_file\|replace | `check-file-change.sh` |

The scripts are agent-agnostic — they read JSON from stdin and output JSON to stdout. The hook configuration files handle the mapping.

## License

[Business Source License 1.1](LICENSE) — free for all use except building competing AI verification products. Converts to MIT on 2030-03-08.

## Author

**Roman Belov** — [roman@journeybay.co](mailto:roman@journeybay.co)
