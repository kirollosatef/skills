#!/usr/bin/env bash
# delete_now.sh - delete gist immediately + unschedule
# Usage: delete_now.sh <gist-id>

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
fi

# only clean state if gist deletion actually succeeds, so retry is possible
if gh gist delete "$gist_id" --yes; then
  echo "✓ gist $gist_id deleted"
  remove_from_state() {
    if [[ -f "$STATE_FILE" ]]; then
      jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
  }
  with_lock remove_from_state || err "gist deleted but failed to update state"
else
  rc=$?
  err "gh gist delete failed (exit $rc) — state retained for retry. fix the underlying issue then re-run."
fi
