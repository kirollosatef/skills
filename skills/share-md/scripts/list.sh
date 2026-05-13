#!/usr/bin/env bash
# list.sh - show all currently shared gists with countdown
set -euo pipefail

STATE_FILE="${HOME}/.claude/share-md/scheduled.json"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "no shares yet"
  exit 0
fi

count=$(jq 'length' "$STATE_FILE")
if [[ "$count" -eq 0 ]]; then
  echo "no active shares"
  exit 0
fi

now=$(date +%s)

# emit each record as a single base64-encoded JSON object so filenames with
# tabs/newlines/quotes round-trip cleanly. tonumber? guards against state-file
# corruption — invalid epochs report INVALID instead of producing null math.
jq -r --argjson now "$now" '
  .[] | {
    gist_id, filename, ttl, delete_at, raw_url,
    remaining: (
      if .target_epoch == "never" then "never"
      elif (.target_epoch | tonumber? // null) == null then "INVALID"
      else ((.target_epoch | tonumber) - $now | tostring) end
    )
  } | @base64
' "$STATE_FILE" | while read -r b64; do
  decoded=$(printf '%s' "$b64" | base64 --decode)
  gist_id=$(printf '%s' "$decoded" | jq -r .gist_id)
  filename=$(printf '%s' "$decoded" | jq -r .filename)
  ttl=$(printf '%s' "$decoded" | jq -r .ttl)
  delete_at=$(printf '%s' "$decoded" | jq -r .delete_at)
  raw_url=$(printf '%s' "$decoded" | jq -r .raw_url)
  remaining=$(printf '%s' "$decoded" | jq -r .remaining)

  if [[ "$remaining" == "never" ]]; then
    countdown="never"
  elif [[ "$remaining" == "INVALID" ]]; then
    countdown="INVALID (state corrupted; cancel + reshare)"
  elif [[ "$remaining" -lt 0 ]] 2>/dev/null; then
    countdown="EXPIRED (cleanup pending)"
  else
    h=$((remaining / 3600))
    m=$(((remaining % 3600) / 60))
    s=$((remaining % 60))
    countdown="${h}h ${m}m ${s}s"
  fi

  echo "─────────────────────────────────────────"
  echo "ID:        $gist_id"
  echo "File:      $filename"
  echo "TTL:       $ttl"
  echo "Expires:   $delete_at"
  echo "Countdown: $countdown"
  echo "Raw URL:   $raw_url"
done
echo "─────────────────────────────────────────"
echo "Total: $count"
