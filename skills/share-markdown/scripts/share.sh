#!/usr/bin/env bash
# share.sh - share a markdown file via secret gist with optional auto-delete
# Usage: share.sh <file> <ttl>
#   ttl: 30m, 1h, 24h, 7d, never

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.claude/share-markdown"
STATE_FILE="${STATE_DIR}/scheduled.json"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL_PREFIX="com.kiro.share-markdown"

mkdir -p "$STATE_DIR" "$LAUNCH_AGENTS_DIR"
[[ -f "$STATE_FILE" ]] || echo '[]' > "$STATE_FILE"

err() { echo "error: $*" >&2; exit 1; }

file="${1:-}"
ttl="${2:-}"

[[ -n "$file" ]] || err "file path required (arg 1)"
[[ -n "$ttl" ]] || err "ttl required (arg 2). use 30m, 1h, 24h, 7d, or never"
[[ -f "$file" ]] || err "file not found: $file"

case "$file" in
  *.md|*.markdown) ;;
  *) echo "warn: file is not .md/.markdown — gist will still render text" >&2 ;;
esac

command -v gh >/dev/null 2>&1 || err "gh CLI not installed. brew install gh"
gh auth status >/dev/null 2>&1 || err "gh not authenticated. run: gh auth login"
command -v jq >/dev/null 2>&1 || err "jq not installed. brew install jq"

GH_BIN=$(command -v gh)
JQ_BIN=$(command -v jq)

# parse ttl -> epoch (or "never")
target_epoch=$(bash "${SCRIPT_DIR}/parse_ttl.sh" "$ttl")

if [[ "$target_epoch" != "never" ]]; then
  now=$(date +%s)
  delta=$((target_epoch - now))
  [[ "$delta" -gt 0 ]] || err "ttl resolves to past time"
  if [[ "$delta" -gt 2592000 ]]; then
    echo "warn: ttl > 30 days. long-lived 'ephemeral' usually mistake. continuing anyway." >&2
  fi
fi

# secret scan (advisory — caller decides to abort)
if scan_output=$(bash "${SCRIPT_DIR}/scan_secrets.sh" "$file"); then
  :
else
  rc=$?
  if [[ "$rc" -eq 2 ]]; then
    echo "WARNING: file contains potential secrets:" >&2
    echo "$scan_output" >&2
    echo "" >&2
    echo "abort with Ctrl-C in next 5s, or wait to continue..." >&2
    sleep 5
  else
    err "secret scan failed (exit $rc)"
  fi
fi

# create secret gist
filename=$(basename "$file")
gist_url=$(gh gist create "$file" --desc "share-markdown: $filename")
gist_id=$(basename "$gist_url")
[[ -n "$gist_id" ]] || err "failed to create gist"

# get raw url
raw_url=$(gh api "gists/${gist_id}" --jq ".files.\"${filename}\".raw_url")
# strip commit sha from raw url for stable form
stable_raw="https://gist.githubusercontent.com/$(gh api user --jq .login)/${gist_id}/raw/${filename}"

# schedule deletion via launchd
plist_path=""
delete_human=""
if [[ "$target_epoch" != "never" ]]; then
  label="${LABEL_PREFIX}.${gist_id}"
  plist_path="${LAUNCH_AGENTS_DIR}/${label}.plist"

  # date components for StartCalendarInterval (local time)
  year=$(date -r "$target_epoch" +%Y)
  month=$(date -r "$target_epoch" +%-m)
  day=$(date -r "$target_epoch" +%-d)
  hour=$(date -r "$target_epoch" +%-H)
  minute=$(date -r "$target_epoch" +%-M)

  delete_human="$(date -r "$target_epoch" "+%Y-%m-%d %H:%M %Z")"

  log_file="${STATE_DIR}/${gist_id}.log"

  cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT_DIR}/_launchd_delete.sh</string>
    <string>${gist_id}</string>
    <string>${plist_path}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Year</key><integer>${year}</integer>
    <key>Month</key><integer>${month}</integer>
    <key>Day</key><integer>${day}</integer>
    <key>Hour</key><integer>${hour}</integer>
    <key>Minute</key><integer>${minute}</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key>
    <string>${HOME}</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${log_file}</string>
  <key>StandardErrorPath</key>
  <string>${log_file}</string>
</dict>
</plist>
PLIST

  launchctl unload "$plist_path" 2>/dev/null || true
  launchctl load "$plist_path"
else
  delete_human="never"
fi

# append to state file
record=$(jq -n \
  --arg gist_id "$gist_id" \
  --arg gist_url "$gist_url" \
  --arg raw_url "$stable_raw" \
  --arg filename "$filename" \
  --arg ttl "$ttl" \
  --arg delete_at "$delete_human" \
  --arg target_epoch "$target_epoch" \
  --arg plist_path "$plist_path" \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{gist_id: $gist_id, gist_url: $gist_url, raw_url: $raw_url, filename: $filename, ttl: $ttl, delete_at: $delete_at, target_epoch: $target_epoch, plist_path: $plist_path, created_at: $created_at}')

jq --argjson rec "$record" '. + [$rec]' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# output
cat <<OUT
✓ Gist created (secret)

Human URL (rendered):
  $gist_url

Agent URL (raw markdown):
  $stable_raw

Auto-delete: $delete_human
Gist ID: $gist_id

Cancel scheduled delete:
  bash ${SCRIPT_DIR}/cancel.sh $gist_id

Delete now:
  bash ${SCRIPT_DIR}/delete_now.sh $gist_id

List all pending:
  bash ${SCRIPT_DIR}/list.sh
OUT
