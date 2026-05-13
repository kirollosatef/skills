#!/usr/bin/env bash
# parse_ttl.sh - convert TTL string to absolute epoch seconds
# Usage: parse_ttl.sh <ttl>
#   ttl forms: 30m, 1h, 24h, 7d, never
# Output: epoch seconds (or "never"), exits 1 on bad input

set -euo pipefail

ttl="${1:-}"

if [[ -z "$ttl" ]]; then
  echo "error: ttl required (e.g. 30m, 1h, 24h, 7d, never)" >&2
  exit 1
fi

if [[ "$ttl" == "never" ]]; then
  echo "never"
  exit 0
fi

if [[ ! "$ttl" =~ ^([0-9]+)(m|h|d)$ ]]; then
  echo "error: bad ttl '$ttl'. use Nm/Nh/Nd or 'never'" >&2
  exit 1
fi

n="${BASH_REMATCH[1]}"
unit="${BASH_REMATCH[2]}"

case "$unit" in
  m) seconds=$((n * 60)) ;;
  h) seconds=$((n * 3600)) ;;
  d) seconds=$((n * 86400)) ;;
esac

if [[ "$seconds" -eq 0 ]]; then
  echo "error: ttl must be > 0" >&2
  exit 1
fi

now=$(date +%s)
target=$((now + seconds))
echo "$target"
