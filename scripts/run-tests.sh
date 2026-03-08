#!/usr/bin/env bash
# TruthGuard — Auto-detect and run tests
# Detects test framework from project files and runs appropriate command
# Returns exit code from test runner

set -euo pipefail

CWD="${1:-.}"
cd "$CWD"

# Detect test framework and run
if [ -f "pubspec.yaml" ]; then
  echo "🧪 TruthGuard: Detected Flutter/Dart project"
  flutter test 2>&1
  exit $?
fi

if [ -f "Cargo.toml" ]; then
  echo "🧪 TruthGuard: Detected Rust project"
  cargo test 2>&1
  exit $?
fi

if [ -f "go.mod" ]; then
  echo "🧪 TruthGuard: Detected Go project"
  go test ./... 2>&1
  exit $?
fi

if [ -f "package.json" ]; then
  # Check for test script in package.json
  if jq -e '.scripts.test' package.json > /dev/null 2>&1; then
    TEST_CMD=$(jq -r '.scripts.test' package.json)
    if [ "$TEST_CMD" != "echo \"Error: no test specified\" && exit 1" ]; then
      echo "🧪 TruthGuard: Detected Node.js project"
      npm test 2>&1
      exit $?
    fi
  fi
fi

if [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.cfg" ]; then
  echo "🧪 TruthGuard: Detected Python project"
  python -m pytest 2>&1
  exit $?
fi

if [ -f "Makefile" ] && grep -q "^test:" Makefile; then
  echo "🧪 TruthGuard: Detected Makefile with test target"
  make test 2>&1
  exit $?
fi

echo "ℹ️ TruthGuard: No test framework detected"
exit 0
