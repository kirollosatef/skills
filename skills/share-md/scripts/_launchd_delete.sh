#!/usr/bin/env bash
# _launchd_delete.sh - run by launchd at scheduled time. Deletes gist + cleans up.
# Usage: _launchd_delete.sh <gist-id> <plist-path>
#
# Order matters: clean up state and delete the plist file BEFORE unloading the
# launchd job — once we unload, this script may receive SIGTERM mid-execution.
# We deliberately don't `set -e` because partial failures (e.g. gist already
# gone) shouldn't abort the rest of cleanup; instead we track whether the gist
# delete succeeded and only prune state on success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

gist_id="${1:-}"
plist_path="${2:-}"

STATE_DIR="${HOME}/.claude/share-md"
STATE_FILE="${STATE_DIR}/scheduled.json"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

[[ -n "$gist_id" ]] || exit 1

# shellcheck source=_with_lock.sh
. "${SCRIPT_DIR}/_with_lock.sh"

# 1. attempt gist delete; remember success
gist_deleted=0
if gh gist delete "$gist_id" --yes 2>&1; then
  gist_deleted=1
fi

# 2. remove from state ONLY if gist deletion succeeded — keeps state and reality
#    in sync. If the gist still exists, we leave its state record so a human or
#    `delete_now.sh` can finish the job.
if [[ "$gist_deleted" -eq 1 ]] && [[ -f "$STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
  remove_from_state() {
    jq --arg id "$gist_id" 'map(select(.gist_id != $id))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  }
  with_lock remove_from_state || true
fi

# 3. cmux desktop notification (no-op if cmux not installed)
if command -v cmux >/dev/null 2>&1; then
  if [[ "$gist_deleted" -eq 1 ]]; then
    cmux notify --title "share-md" --body "Gist ${gist_id} auto-deleted (${SHARE_MD_FILENAME:-unknown})" 2>/dev/null || true
  else
    cmux notify --title "share-md (FAILED)" --body "Could not delete gist ${gist_id} — state retained for retry" 2>/dev/null || true
  fi
fi

# 4. remove plist file BEFORE unloading (so we don't get SIGTERM mid-rm)
if [[ -n "$plist_path" && -f "$plist_path" ]]; then
  rm -f "$plist_path"
fi

# 5. unload self last (may SIGTERM us; cleanup already done)
if [[ -n "$plist_path" ]]; then
  label=$(basename "$plist_path" .plist)
  launchctl bootout "gui/${UID}/${label}" 2>&1 || launchctl unload "$plist_path" 2>&1 || true
fi

exit 0
