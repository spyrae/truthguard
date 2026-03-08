#!/usr/bin/env bash
# TruthGuard — PostToolUse (Bash): verify exit code matches actual outcome
# Catches cases where command fails but AI might claim success
# Blocks on test/build failures, warns on other non-zero exit codes

set -euo pipefail

LOG="/tmp/truthguard-session.log"

# Read all input once into a variable
INPUT=$(cat)

# Extract tool response data
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""')
STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // ""')
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0')

# Exit code 0 — all good
if [ "$EXIT_CODE" = "0" ]; then
  exit 0
fi

# --- Edge cases: commands where non-zero exit is normal ---

# grep/rg with no matches returns 1 — not an error
if echo "$COMMAND" | grep -qE '(^|\||\s)(grep|rg|egrep|fgrep)\s' && [ "$EXIT_CODE" = "1" ]; then
  exit 0
fi

# diff returns 1 when files differ — expected behavior
if echo "$COMMAND" | grep -qE '(^|\||\s)diff\s' && [ "$EXIT_CODE" = "1" ]; then
  exit 0
fi

# test/[ returns 1 for false condition — not an error
if echo "$COMMAND" | grep -qE '(^|\s)(test|\[)\s' && [ "$EXIT_CODE" = "1" ]; then
  exit 0
fi

# Commands in conditionals (if/||/&&) with non-fatal exit codes
if echo "$COMMAND" | grep -qE '\|\||&&|^\s*if\s'; then
  if [ "$EXIT_CODE" -lt 128 ] 2>/dev/null; then
    exit 0
  fi
fi

# --- Combine output for pattern matching ---
COMBINED_OUTPUT="${STDOUT}
${STDERR}"

# Get last 15 lines for context
TAIL_OUTPUT=$(echo "$COMBINED_OUTPUT" | tail -15)

# --- Build/compile failure detection: BLOCK (check before test patterns) ---
BUILD_FAIL_PATTERNS="BUILD FAILED|build failed|compilation error|compile error|SyntaxError|cannot find module|Module not found"
if echo "$COMBINED_OUTPUT" | grep -qiE "$BUILD_FAIL_PATTERNS"; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) build-fail exit=$EXIT_CODE $COMMAND" >> "$LOG"
  REASON="Command exited with code ${EXIT_CODE}. Build/compilation failures detected. Fix the errors before proceeding."
  MSG="🛑 TruthGuard: Build failure detected (exit code ${EXIT_CODE})."
  jq -n \
    --arg reason "$REASON" \
    --arg context "$TAIL_OUTPUT" \
    --arg msg "$MSG" \
    '{decision: "block", reason: ($reason + "\n\nLast lines of output:\n" + $context), systemMessage: $msg}'
  exit 0
fi

# --- Test failure detection: BLOCK ---
TEST_FAIL_PATTERNS="test.*FAILED|FAIL:|failures?:|errors? found|test.*failed|AssertionError|assert.*failed|FAILURES!|Tests:.*failed|failing test|pytest.*error"
if echo "$COMBINED_OUTPUT" | grep -qiE "$TEST_FAIL_PATTERNS"; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) test-fail exit=$EXIT_CODE $COMMAND" >> "$LOG"
  REASON="Command exited with code ${EXIT_CODE}. Test failures detected in output. You MUST acknowledge these failures and fix them before proceeding. Do NOT claim tests passed."
  MSG="🛑 TruthGuard: Test failures detected (exit code ${EXIT_CODE}). Agent must fix before continuing."
  jq -n \
    --arg reason "$REASON" \
    --arg context "$TAIL_OUTPUT" \
    --arg msg "$MSG" \
    '{decision: "block", reason: ($reason + "\n\nLast lines of output:\n" + $context), systemMessage: $msg}'
  exit 0
fi

# --- Generic non-zero exit code: BLOCK with softer message ---
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) exit-code exit=$EXIT_CODE $COMMAND" >> "$LOG"
REASON="Command exited with code ${EXIT_CODE}. Review the output and acknowledge the actual result before proceeding."
MSG="⚠️ TruthGuard: Command exited with code ${EXIT_CODE}. Verify the actual result before claiming success."
jq -n \
  --arg reason "$REASON" \
  --arg context "$TAIL_OUTPUT" \
  --arg msg "$MSG" \
  '{decision: "block", reason: ($reason + "\n\nLast lines:\n" + $context), systemMessage: $msg}'
exit 0
