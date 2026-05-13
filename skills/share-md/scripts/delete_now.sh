#!/usr/bin/env bash
# delete_now.sh - delete gist immediately + unschedule
# Usage: delete_now.sh <gist-id>

set -euo pipefail

STATE_FILE="${HOME}/.claude/share-md/scheduled.json"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL_PREFIX="com.kiro.share-md"

gist_id="${1:-}"
[[ -n "$gist_id" ]] || { echo "error: gist-id required" >&2; exit 1; }

plist_path="${LAUNCH_AGENTS_DIR}/${LABEL_PREFIX}.${gist_id}.plist"
if [[ -f "$plist_path" ]]; then
  rm -f "$plist_path"
  launchctl bootout "gui/${UID}/${LABEL_PREFIX}.${gist_id}" 2>/dev/null || launchctl unload "$plist_path" 2>/dev/null || true
fi

gh gist delete "$gist_id" --yes
echo "✓ gist $gist_id deleted"

if [[ -f "$STATE_FILE" ]]; then
  jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi
