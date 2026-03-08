#!/usr/bin/env bash
# TruthGuard — PreToolUse (Bash): block dangerous commands
# Blocks: --no-verify, --force push, rm -rf on critical dirs, reset --hard

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Patterns to block
if echo "$COMMAND" | grep -qE 'git\s+commit\s+.*--no-verify|git\s+commit\s+.*-n\b'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"🛑 TruthGuard: Blocked git commit --no-verify. Skipping hooks defeats the purpose of verification."}}'
  exit 0
fi

if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force\b|git\s+push\s+.*-f\b'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"🛑 TruthGuard: Blocked git push --force. Use --force-with-lease if you must."}}'
  exit 0
fi

if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"⚠️ TruthGuard: git reset --hard will discard uncommitted changes. Are you sure?"}}'
  exit 0
fi

if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+(/|~|\$HOME|\.git)\b'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"🛑 TruthGuard: Blocked rm -rf on critical directory."}}'
  exit 0
fi

# Allow everything else
exit 0
