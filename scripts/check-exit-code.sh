#!/usr/bin/env bash
# TruthGuard — PostToolUse (Bash): verify exit code matches claimed outcome
# Catches cases where command fails but AI claims success

set -euo pipefail

INPUT=$(cat)

# Extract tool result data
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
STDOUT=$(echo "$INPUT" | jq -r '.tool_result.stdout // ""')
STDERR=$(echo "$INPUT" | jq -r '.tool_result.stderr // ""')
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // "0"')

# Only care about non-zero exit codes
if [ "$EXIT_CODE" = "0" ]; then
  exit 0
fi

# Check if output contains test failure indicators
TEST_FAIL_PATTERNS="FAILED|FAIL:|failures?:|errors? found|test.*failed|AssertionError|assert.*failed"
if echo "$STDOUT$STDERR" | grep -qiE "$TEST_FAIL_PATTERNS"; then
  echo "{\"systemMessage\":\"⚠️ TruthGuard: Command exited with code $EXIT_CODE and output contains test failures. Do NOT claim tests passed.\"}"
  exit 0
fi

# Generic non-zero exit code warning
echo "{\"systemMessage\":\"⚠️ TruthGuard: Command exited with code $EXIT_CODE. Verify the actual result before claiming success.\"}"
exit 0
