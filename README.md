# TruthGuard

[![Version](https://img.shields.io/badge/version-0.1.0-blue)](https://github.com/spyrae/truthguard)
[![License](https://img.shields.io/badge/license-BUSL--1.1-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-hooks-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![Gemini CLI](https://img.shields.io/badge/Gemini%20CLI-extension-orange)](https://github.com/google-gemini/gemini-cli)

**Catches false claims from AI coding agents.** Verifies that actions were actually performed - not just claimed.

![TruthGuard Demo](docs/demo.gif)

## The Problem

AI coding agents systematically claim things they didn't do:

- "All tests pass!" - tests were never run ([claude-code#1501](https://github.com/anthropics/claude-code/issues/1501))
- "I updated the file" - file content is identical
- "Done, committing" - with failing tests, using `--no-verify`
- `git push --force` - without asking

These aren't malicious. They're hallucinations and shortcuts. But **unverified claims break production.**

## How It Works

TruthGuard hooks into the agent's tool call pipeline and verifies results in real-time:

```
Agent decides to run a command
        |
   [PreToolUse] -- block dangerous commands, run tests before commit
        |
   Command executes
        |
   [PostToolUse] -- verify exit code, check file checksums, remind to verify
```

### Hook Overview

| Hook | Type | What it catches |
|------|------|-----------------|
| **Dangerous Command Blocker** | PreToolUse | `--no-verify`, `--force push`, `rm -rf /`, `reset --hard` |
| **Pre-Commit Test Runner** | PreToolUse | Auto-detects project, runs tests before every `git commit` |
| **File Checksum Recorder** | PreToolUse | Saves SHA256 before file edit (for phantom edit detection) |
| **Exit Code Verifier** | PostToolUse | Command failed but agent might claim success |
| **Phantom Edit Detector** | PostToolUse | Agent claims edit, but file checksum unchanged |
| **Commit Verification Reminder** | PostToolUse | Forces agent to verify fix works before claiming "done" |

### Supported Test Frameworks

Pre-commit hook auto-detects: **Flutter** / **Node.js** (npm test) / **Python** (pytest) / **Rust** (cargo test) / **Go** (go test) / **Makefile** (make test)

## Quick Start

### Claude Code

**1. Clone:**

```bash
git clone https://github.com/spyrae/truthguard.git ~/.truthguard
```

**2. Add to your project's `.claude/settings.json`:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ~/.truthguard/scripts/block-dangerous.sh", "timeout": 5 },
          { "type": "command", "command": "bash ~/.truthguard/scripts/pre-commit-tests.sh", "timeout": 120 }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash ~/.truthguard/scripts/pre-file-change.sh", "timeout": 5 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ~/.truthguard/scripts/check-exit-code.sh", "timeout": 10 },
          { "type": "command", "command": "bash ~/.truthguard/scripts/post-commit-remind.sh", "timeout": 5 }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash ~/.truthguard/scripts/check-file-change.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

**3. Restart Claude Code.** Hooks activate on session start.

### Gemini CLI

```bash
gemini extensions install https://github.com/spyrae/truthguard
```

Hooks load automatically via the extension system.

## What You'll See

When TruthGuard catches something:

```
🛑 TruthGuard: Blocked git push --force. Use --force-with-lease for safer force push.
```

```
🛑 TruthGuard: Test failures detected (exit code 1). Agent must fix before continuing.
```

```
⚠️ TruthGuard: File 'utils.dart' was not actually modified. Checksum unchanged.
```

```
⚠️ TruthGuard: Commit successful. Verify the fix works before claiming done.
```

## Real-World Results

Dogfooding on a production Flutter project (2 days):

| Event | Count | What happened |
|-------|-------|---------------|
| Pre-commit test blocks | 5 | Agent tried to commit with failing tests - blocked every time |
| Dangerous command blocks | 3 | `git push --force` and `git commit --no-verify` - blocked |
| Verification reminders | Active | Agent now acknowledges verification after each commit |

**Zero false positives.** Every block was a real issue.

## Configuration

Create `.truthguard.yml` in your project root:

```yaml
# Override auto-detected test command
test_command: "npm run test:unit"

# Block commit if no tests found (default: true = skip)
skip_on_no_tests: false
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TRUTHGUARD_LOG` | `~/.truthguard/session.log` | Session log location |
| `TRUTHGUARD_CHECKSUMS` | `~/.truthguard/checksums/` | Checksum storage directory |

### Slash Commands (Claude Code)

- `/verify` - Run tests + type checks + linting with auto-detection
- `/truthguard-status` - Show session statistics

## Requirements

- `jq` - JSON processing (most systems have it; `brew install jq` / `apt install jq`)
- `bash` 4+
- `shasum` or `sha256sum`

## Project Structure

```
truthguard/
├── scripts/
│   ├── block-dangerous.sh      # PreToolUse: block risky git commands
│   ├── pre-commit-tests.sh     # PreToolUse: run tests before commit
│   ├── pre-file-change.sh      # PreToolUse: record file checksums
│   ├── check-exit-code.sh      # PostToolUse: verify exit codes
│   ├── check-file-change.sh    # PostToolUse: detect phantom edits
│   ├── post-commit-remind.sh   # PostToolUse: verification reminder
│   └── run-tests.sh            # Helper: auto-detect and run tests
├── hooks/
│   ├── hooks.json              # Claude Code hook configuration
│   └── gemini.json             # Gemini CLI hook configuration
├── skills/
│   ├── verify/SKILL.md         # /verify slash command
│   └── status/SKILL.md         # /truthguard-status slash command
├── .claude-plugin/
│   └── plugin.json             # Claude Code plugin manifest
├── gemini-extension.json       # Gemini CLI extension manifest
├── GEMINI.md                   # Context injected into Gemini sessions
├── .truthguard.yml.example     # Example configuration
├── LICENSE                     # BUSL-1.1 (converts to MIT 2030-03-08)
└── README.md
```

## How Hooks Map Between Agents

| Claude Code | Gemini CLI | Script |
|-------------|------------|--------|
| PreToolUse -> Bash | BeforeTool -> run_shell_command | `block-dangerous.sh`, `pre-commit-tests.sh` |
| PreToolUse -> Write\|Edit | BeforeTool -> write_file\|replace | `pre-file-change.sh` |
| PostToolUse -> Bash | AfterTool -> run_shell_command | `check-exit-code.sh`, `post-commit-remind.sh` |
| PostToolUse -> Write\|Edit | AfterTool -> write_file\|replace | `check-file-change.sh` |

Scripts are agent-agnostic: read JSON from stdin, output JSON to stdout. Hook configs handle the mapping.

## License

[Business Source License 1.1](LICENSE) - free for all use except building competing AI verification products. Converts to MIT on 2030-03-08.

## Author

**Roman Belov** - [GitHub](https://github.com/spyrae)
