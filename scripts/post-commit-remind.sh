#!/usr/bin/env bash
# TruthGuard — PostToolUse (Bash): remind to verify after commit
# After a successful git commit, forces Claude to acknowledge
# that visual/functional verification is needed before claiming "done"

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0')

# Only trigger on successful git commit
if ! echo "$COMMAND" | grep -qE 'git\s+commit\b'; then
  exit 0
fi

if [ "$EXIT_CODE" != "0" ]; then
  exit 0
fi

# Log the reminder
LOG="${TRUTHGUARD_LOG:-$HOME/.truthguard/session.log}"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) commit-verify-reminder" >> "$LOG"

# Inject verification reminder into Claude's context
REASON="You just committed code. STOP and verify: did you actually confirm the fix works? Run the app, take a screenshot, or run relevant tests to prove the change solves the problem. Do NOT mark the task as done without evidence."
MSG="⚠️ TruthGuard: Commit successful. Verify the fix works before claiming done."

jq -n \
  --arg reason "$REASON" \
  --arg msg "$MSG" \
  '{decision: "block", reason: $reason, systemMessage: $msg}'
exit 0
