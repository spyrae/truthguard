#!/usr/bin/env bash
# TruthGuard — PreToolUse (Bash): run tests before git commit
# Intercepts git commit commands and runs project tests first
# Blocks commit if tests fail; skips if no tests found

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Only intercept git commit commands
if ! echo "$COMMAND" | grep -qE 'git\s+commit\b'; then
  exit 0
fi

# Skip if this is an amend with no code changes (message-only amend)
if echo "$COMMAND" | grep -qE 'git\s+commit\s+--amend\s+(-m|--message)'; then
  exit 0
fi

# --- Check for custom test command in .truthguard.yml ---
TEST_CMD=""
SKIP_ON_NO_TESTS="true"
CONFIG_FILE="$CWD/.truthguard.yml"

if [ -f "$CONFIG_FILE" ]; then
  # Parse simple YAML (test_command and skip_on_no_tests)
  RAW_CMD=$(grep -E '^\s*test_command:' "$CONFIG_FILE" 2>/dev/null | sed 's/.*test_command:[[:space:]]*//' || true)
  # Strip surrounding quotes (single or double) and trim whitespace
  TEST_CMD=$(echo "$RAW_CMD" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
  SKIP_VAL=$(grep -E '^\s*skip_on_no_tests:' "$CONFIG_FILE" 2>/dev/null | sed 's/.*skip_on_no_tests:[[:space:]]*//' || true)
  if [ "$SKIP_VAL" = "false" ]; then
    SKIP_ON_NO_TESTS="false"
  fi
fi

# --- Auto-detect test framework if no custom command ---
if [ -z "$TEST_CMD" ]; then
  if [ -f "$CWD/pubspec.yaml" ]; then
    TEST_CMD="flutter test"
  elif [ -f "$CWD/Cargo.toml" ]; then
    TEST_CMD="cargo test"
  elif [ -f "$CWD/go.mod" ]; then
    TEST_CMD="go test ./..."
  elif [ -f "$CWD/package.json" ]; then
    # Check for test script
    if jq -e '.scripts.test' "$CWD/package.json" > /dev/null 2>&1; then
      PKG_TEST=$(jq -r '.scripts.test' "$CWD/package.json")
      if [ "$PKG_TEST" != "echo \"Error: no test specified\" && exit 1" ]; then
        TEST_CMD="npm test"
      fi
    fi
  elif [ -f "$CWD/pyproject.toml" ] || [ -f "$CWD/pytest.ini" ] || [ -f "$CWD/setup.cfg" ]; then
    TEST_CMD="python -m pytest"
  elif [ -f "$CWD/Makefile" ] && grep -q "^test:" "$CWD/Makefile"; then
    TEST_CMD="make test"
  fi
fi

# --- No tests found ---
if [ -z "$TEST_CMD" ]; then
  if [ "$SKIP_ON_NO_TESTS" = "true" ]; then
    exit 0
  else
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "🛑 TruthGuard: No test framework detected and skip_on_no_tests is false. Add tests or set skip_on_no_tests: true in .truthguard.yml"
      }
    }'
    exit 0
  fi
fi

# --- Run tests ---
TEST_OUTPUT=$(cd "$CWD" && eval "$TEST_CMD" 2>&1) || TEST_EXIT=$?
TEST_EXIT=${TEST_EXIT:-0}

if [ "$TEST_EXIT" != "0" ]; then
  # Tests failed — block the commit
  TAIL_OUTPUT=$(echo "$TEST_OUTPUT" | tail -20)
  REASON="Tests failed (exit code ${TEST_EXIT}). Fix the failures before committing. Test command: ${TEST_CMD}"
  jq -n \
    --arg reason "$REASON" \
    --arg output "$TAIL_OUTPUT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ("🛑 TruthGuard: " + $reason + "\n\nTest output:\n" + $output)
      }
    }'
  exit 0
fi

# Tests passed — allow the commit
exit 0
