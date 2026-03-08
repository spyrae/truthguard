#!/usr/bin/env bash
# TruthGuard — PostToolUse (Write|Edit): verify file actually changed
# Compares checksum before and after to catch phantom edits

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

CHECKSUM_DIR="/tmp/truthguard-checksums"
ENCODED_PATH=$(echo "$FILE_PATH" | md5sum | cut -d' ' -f1 2>/dev/null || md5 -q -s "$FILE_PATH")
CHECKSUM_FILE="$CHECKSUM_DIR/$ENCODED_PATH"

# If no pre-change checksum exists, skip (new file creation is fine)
if [ ! -f "$CHECKSUM_FILE" ]; then
  exit 0
fi

# Compare checksums
OLD_CHECKSUM=$(cat "$CHECKSUM_FILE" | cut -d' ' -f1)
NEW_CHECKSUM=$(sha256sum "$FILE_PATH" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$FILE_PATH" | cut -d' ' -f1)

# Clean up
rm -f "$CHECKSUM_FILE"

if [ "$OLD_CHECKSUM" = "$NEW_CHECKSUM" ]; then
  BASENAME=$(basename "$FILE_PATH")
  echo "{\"systemMessage\":\"⚠️ TruthGuard: File '$BASENAME' was not actually modified. Checksum unchanged.\"}"
  exit 0
fi

exit 0
