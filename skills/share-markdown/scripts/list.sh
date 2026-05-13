#!/usr/bin/env bash
# list.sh - show all currently shared gists with countdown
set -euo pipefail

STATE_FILE="${HOME}/.claude/share-markdown/scheduled.json"

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

jq -r --argjson now "$now" '
  .[] | [
    .gist_id,
    .filename,
    .ttl,
    .delete_at,
    (if .target_epoch == "never" then "never" else ((.target_epoch | tonumber) - $now | tostring) end),
    .raw_url
  ] | @tsv
' "$STATE_FILE" | while IFS=$'\t' read -r gist_id filename ttl delete_at remaining raw_url; do
  if [[ "$remaining" == "never" ]]; then
    countdown="never"
  elif [[ "$remaining" -lt 0 ]]; then
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
