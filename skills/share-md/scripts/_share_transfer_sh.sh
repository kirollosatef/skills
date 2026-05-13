#!/usr/bin/env bash
# _share_transfer_sh.sh - upload to transfer.sh with optional one-time download
# Usage: _share_transfer_sh.sh <file> <ttl-days> [--once]
#
# transfer.sh has native support for:
#   - Max-Days header (auto-delete after N days, max 14)
#   - Max-Downloads header (one-time view via Max-Downloads: 1)
#
# This is the only backend that supports true burn-after-read; the gist
# backend can only auto-delete on a timer, not on first fetch.

set -euo pipefail

file="${1:-}"
ttl_days="${2:-1}"
once_flag="${3:-}"

err() { echo "error: $*" >&2; exit 1; }

[[ -n "$file" && -f "$file" ]] || err "file path required"
[[ "$ttl_days" =~ ^[0-9]+$ ]] || err "ttl-days must be integer (max 14)"
[[ "$ttl_days" -gt 0 && "$ttl_days" -le 14 ]] || err "ttl-days must be 1..14"

command -v curl >/dev/null 2>&1 || err "curl not installed"

filename=$(basename "$file")

# build curl args
args=( --upload-file "$file" -H "Max-Days: $ttl_days" )
if [[ "$once_flag" == "--once" ]]; then
  args+=( -H "Max-Downloads: 1" )
fi

# Only transfer.sh has the right API (PUT + Max-Days/Max-Downloads headers,
# raw response body). Alternatives like temp.sh wrap downloads in HTML, which
# breaks agent fetch. If transfer.sh is unreachable, surface a clear error.
url=$(curl -fsSL --connect-timeout 5 "${args[@]}" "https://transfer.sh/${filename}" 2>&1) || {
  err "transfer.sh unreachable. service may be rate-limiting your IP, blocked, or temporarily down. retry later or use the default gist backend (without --once)."
}

[[ -n "$url" ]] || err "transfer.sh returned empty URL"

cat <<OUT
✓ Uploaded to transfer.sh

URL:
  $url

Auto-delete: after ${ttl_days} day(s)
$([[ "$once_flag" == "--once" ]] && echo "One-time download: yes (becomes 404 after first fetch)")

Recipient fetches with:
  curl -sL "$url"
OUT
