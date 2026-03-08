#!/usr/bin/env bash
# TruthGuard — PreToolUse (Write|Edit): record file checksum before change
# Stores checksum in /tmp/truthguard-checksums/ for post-change verification

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Create temp dir for checksums
CHECKSUM_DIR="/tmp/truthguard-checksums"
mkdir -p "$CHECKSUM_DIR"

# Store checksum with encoded path as filename
ENCODED_PATH=$(echo "$FILE_PATH" | md5sum | cut -d' ' -f1 2>/dev/null || md5 -q -s "$FILE_PATH")
sha256sum "$FILE_PATH" 2>/dev/null > "$CHECKSUM_DIR/$ENCODED_PATH" || shasum -a 256 "$FILE_PATH" > "$CHECKSUM_DIR/$ENCODED_PATH"

exit 0
