#!/usr/bin/env bash
# _launchd_delete.sh - run by launchd at scheduled time. Deletes gist + cleans up.
# Usage: _launchd_delete.sh <gist-id> <plist-path>
#
# Order matters: clean up state and delete the plist file BEFORE unloading the
# launchd job — once we unload, this script may receive SIGTERM mid-execution.

set -uo pipefail

gist_id="${1:-}"
plist_path="${2:-}"

STATE_FILE="${HOME}/.claude/share-md/scheduled.json"

# need PATH so we find gh/jq
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

[[ -n "$gist_id" ]] || exit 1

# 1. delete gist (--yes is required in non-interactive context)
gh gist delete "$gist_id" --yes 2>&1 || true

# 2. remove from state file
if [[ -f "$STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
  jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# 3. remove plist file BEFORE unloading (so we don't get killed mid-rm)
if [[ -n "$plist_path" && -f "$plist_path" ]]; then
  rm -f "$plist_path"
fi

# 4. unload self last (may SIGTERM us; that's OK, all cleanup already done)
if [[ -n "$plist_path" ]]; then
  label=$(basename "$plist_path" .plist)
  launchctl bootout "gui/${UID}/${label}" 2>&1 || launchctl unload "$plist_path" 2>&1 || true
fi

exit 0
