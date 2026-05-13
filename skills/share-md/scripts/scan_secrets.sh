#!/usr/bin/env bash
# scan_secrets.sh - scan a file for credential-looking patterns
# Usage: scan_secrets.sh <file>
# Exit 0 = clean, exit 2 = matches found (printed to stdout), exit 1 = error

set -euo pipefail

file="${1:-}"

if [[ -z "$file" || ! -f "$file" ]]; then
  echo "error: file not found: $file" >&2
  exit 1
fi

# refuse files larger than 1 MB — grep on huge or binary files can hang or
# OOM the host. Markdown shares should never be that large; if a user really
# wants to share a huge file they can split or use a different tool.
SIZE_LIMIT_BYTES=$((1024 * 1024))
size=$(stat -f %z "$file" 2>/dev/null || stat -c %s "$file" 2>/dev/null || echo 0)
if [[ "$size" -gt "$SIZE_LIMIT_BYTES" ]]; then
  echo "error: file too large for secret scan ($size bytes > ${SIZE_LIMIT_BYTES}). split it or use a different tool." >&2
  exit 1
fi

matches=()

scan() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -nE -- "$pattern" "$file" || true)
  if [[ -n "$hits" ]]; then
    matches+=("[$label]")
    matches+=("$hits")
    matches+=("")
  fi
}

scan "AWS access key" 'AKIA[0-9A-Z]{16}'
scan "GitHub PAT (classic)" 'ghp_[A-Za-z0-9]{36}'
scan "GitHub PAT (fine-grained)" 'github_pat_[A-Za-z0-9_]{82}'
scan "OpenAI key" 'sk-[A-Za-z0-9]{20,}'
scan "Anthropic key" 'sk-ant-[A-Za-z0-9_-]{20,}'
scan "Slack token" 'xox[abprs]-[A-Za-z0-9-]{10,}'
scan "Generic password assignment" '(^|[^a-zA-Z_])(password|passwd|pwd)[[:space:]]*[:=][[:space:]]*[^[:space:]]+'
scan "Generic api_key/secret assignment" '(api[_-]?key|api[_-]?secret|secret[_-]?key|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*[^[:space:]]+'
scan "Private key block" '-----BEGIN ([A-Z ]+)?PRIVATE KEY-----'
scan "Bearer token" 'Bearer [A-Za-z0-9._-]{20,}'

if [[ ${#matches[@]} -gt 0 ]]; then
  printf '%s\n' "${matches[@]}"
  exit 2
fi

exit 0
