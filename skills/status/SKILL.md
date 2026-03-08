---
name: truthguard-status
description: Show TruthGuard session statistics
allowed-tools: Bash
---

Show the current TruthGuard session status.

## Steps

1. Check if TruthGuard hooks are active by examining the Claude Code settings
2. Count any warnings issued in the current session (check /tmp/truthguard-* files)
3. Report status in this format:

```
🛡️ TruthGuard Status
━━━━━━━━━━━━━━━━━━━
Hooks active: ✅ PostToolUse (Bash, Write/Edit) | PreToolUse (Bash)
Session warnings: X blocked, Y file-check alerts, Z exit-code warnings
```
