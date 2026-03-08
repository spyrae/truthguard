#!/usr/bin/env bash
# TruthGuard — PostToolUse (Write|Edit): verify file actually changed
# Compares checksum before and after to catch phantom edits
# Blocks if file content unchanged after claimed modification

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# No file path — skip
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# File doesn't exist after Write/Edit — likely an error, but not our concern
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

CHECKSUM_DIR="/tmp/truthguard-checksums"
ENCODED_PATH=$(echo "$FILE_PATH" | md5sum | cut -d' ' -f1 2>/dev/null || md5 -q -s "$FILE_PATH")
CHECKSUM_FILE="$CHECKSUM_DIR/$ENCODED_PATH"

# If no pre-change checksum exists, this is a new file creation — always OK
if [ ! -f "$CHECKSUM_FILE" ]; then
  exit 0
fi

# Compare checksums
OLD_CHECKSUM=$(cat "$CHECKSUM_FILE" | cut -d' ' -f1)
NEW_CHECKSUM=$(sha256sum "$FILE_PATH" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$FILE_PATH" | cut -d' ' -f1)

# Clean up stored checksum
rm -f "$CHECKSUM_FILE"

if [ "$OLD_CHECKSUM" = "$NEW_CHECKSUM" ]; then
  BASENAME=$(basename "$FILE_PATH")
  REASON="File '${BASENAME}' was not actually modified — checksum is identical before and after the operation. If you intended to change this file, review your edit. Do NOT claim the file was updated."
  MSG="⚠️ TruthGuard: File '${BASENAME}' was not actually modified. Checksum unchanged."
  jq -n \
    --arg reason "$REASON" \
    --arg msg "$MSG" \
    '{decision: "block", reason: $reason, systemMessage: $msg}'
  exit 0
fi

exit 0
