#!/usr/bin/env bash
# cancel.sh - cancel scheduled deletion (gist persists)
# Usage: cancel.sh <gist-id>

set -euo pipefail

STATE_FILE="${HOME}/.claude/share-markdown/scheduled.json"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL_PREFIX="com.kiro.share-markdown"

gist_id="${1:-}"
[[ -n "$gist_id" ]] || { echo "error: gist-id required" >&2; exit 1; }

plist_path="${LAUNCH_AGENTS_DIR}/${LABEL_PREFIX}.${gist_id}.plist"

if [[ -f "$plist_path" ]]; then
  rm -f "$plist_path"
  launchctl bootout "gui/${UID}/${LABEL_PREFIX}.${gist_id}" 2>/dev/null || launchctl unload "$plist_path" 2>/dev/null || true
  echo "✓ scheduled delete cancelled for gist $gist_id"
else
  echo "no scheduled delete found for gist $gist_id (may already have fired or never scheduled)"
fi

if [[ -f "$STATE_FILE" ]]; then
  jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "removed from tracking"
fi

echo "gist still live at: https://gist.github.com/$(gh api user --jq .login)/$gist_id"
