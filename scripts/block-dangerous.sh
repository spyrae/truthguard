#!/usr/bin/env bash
# TruthGuard — PreToolUse (Bash): block dangerous commands
# Blocks: --no-verify, --force push, rm -rf on critical dirs, reset --hard
# Warns: --force-with-lease, checkout -- (discards changes)

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

LOG="/tmp/truthguard-session.log"

deny() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) blocked $COMMAND" >> "$LOG"
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

ask() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) blocked $COMMAND" >> "$LOG"
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

# --- DENY: git commit --no-verify / -n ---
if echo "$COMMAND" | grep -qE -- 'git\s+commit\s+.*--no-verify|git\s+commit\s+.*\s-n\b'; then
  deny "🛑 TruthGuard: Blocked git commit --no-verify. Skipping hooks defeats the purpose of verification."
fi

# --- ASK: git push --force-with-lease (check BEFORE --force to avoid false deny) ---
if echo "$COMMAND" | grep -qE -- 'git\s+push\b.*force-with-lease'; then
  ask "⚠️ TruthGuard: git push --force-with-lease is safer than --force but still rewrites remote history. Are you sure?"
fi

# --- DENY: git push --force / -f (not --force-with-lease) ---
if echo "$COMMAND" | grep -qE -- 'git\s+push\b.*\s--force($|\s)|git\s+push\b.*\s-f($|\s)'; then
  deny "🛑 TruthGuard: Blocked git push --force. Use --force-with-lease for safer force push."
fi

# --- ASK: git reset --hard ---
if echo "$COMMAND" | grep -qE -- 'git\s+reset\s+--hard'; then
  ask "⚠️ TruthGuard: git reset --hard will discard all uncommitted changes. Are you sure?"
fi

# --- ASK: git checkout -- (discard file changes) ---
if echo "$COMMAND" | grep -qE -- 'git\s+checkout\s+--\s'; then
  ask "⚠️ TruthGuard: git checkout -- will discard uncommitted changes to files. Are you sure?"
fi

# --- ASK: git clean -f (remove untracked files) ---
if echo "$COMMAND" | grep -qE -- 'git\s+clean\s+.*-f'; then
  ask "⚠️ TruthGuard: git clean -f will permanently delete untracked files. Are you sure?"
fi

# --- DENY: rm -rf on critical directories ---
if echo "$COMMAND" | grep -qE -- 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s+(/($|\s)|~($|\s)|\$HOME($|\s)|\.git($|\s))'; then
  deny "🛑 TruthGuard: Blocked rm -rf on critical directory."
fi

# --- DENY: rm -rf / with various flag orders ---
if echo "$COMMAND" | grep -qE -- 'rm\s+-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*\s+(/($|\s)|~($|\s)|\$HOME($|\s)|\.git($|\s))'; then
  deny "🛑 TruthGuard: Blocked rm -rf on critical directory."
fi

# Allow everything else
exit 0
