#!/usr/bin/env bash
# _launchd_delete.sh - run by launchd at scheduled time. Deletes gist + cleans up.
# Usage: _launchd_delete.sh <gist-id> <plist-path>

set -uo pipefail

gist_id="${1:-}"
plist_path="${2:-}"

STATE_FILE="${HOME}/.claude/share-markdown/scheduled.json"

# need PATH so we find gh/jq
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

[[ -n "$gist_id" ]] || exit 1

# delete gist (may fail if already deleted; ignore)
gh gist delete "$gist_id" --yes 2>&1 || true

# remove from state
if [[ -f "$STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
  jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# unload self + delete plist
if [[ -n "$plist_path" && -f "$plist_path" ]]; then
  launchctl unload "$plist_path" 2>&1 || true
  rm -f "$plist_path"
fi

exit 0
