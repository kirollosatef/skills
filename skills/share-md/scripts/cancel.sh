#!/usr/bin/env bash
# cancel.sh - cancel scheduled deletion (gist persists)
# Usage: cancel.sh <gist-id>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${HOME}/.claude/share-md/scheduled.json"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL_PREFIX="com.kiro.share-md"

err() { echo "error: $*" >&2; exit 1; }

# shellcheck source=_with_lock.sh
. "${SCRIPT_DIR}/_with_lock.sh"

gist_id="${1:-}"
[[ -n "$gist_id" ]] || err "gist-id required"

command -v gh >/dev/null 2>&1 || err "gh CLI not installed. brew install gh"
gh auth status >/dev/null 2>&1 || err "gh not authenticated. run: gh auth login"

plist_path="${LAUNCH_AGENTS_DIR}/${LABEL_PREFIX}.${gist_id}.plist"

if [[ -f "$plist_path" ]]; then
  rm -f "$plist_path"
  launchctl bootout "gui/${UID}/${LABEL_PREFIX}.${gist_id}" 2>/dev/null || launchctl unload "$plist_path" 2>/dev/null || true
  echo "✓ scheduled delete cancelled for gist $gist_id"
else
  echo "no scheduled delete found for gist $gist_id (may already have fired or never scheduled)"
fi

remove_from_state() {
  if [[ -f "$STATE_FILE" ]]; then
    jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  fi
}
with_lock remove_from_state || err "failed to update state file"
echo "removed from tracking"

echo "gist still live at: https://gist.github.com/$(gh api user --jq .login)/$gist_id"
