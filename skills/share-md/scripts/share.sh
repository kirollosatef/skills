#!/usr/bin/env bash
# share.sh - share a markdown file via secret gist with optional auto-delete
# Usage: share.sh <file> <ttl> [flags]
#   ttl:   30m, 1h, 24h, 7d, never
#   flags:
#     --encrypt           encrypt with random passphrase before pushing (gist
#                         contents become ciphertext; recipient needs passphrase)
#     --dry-run           print what would happen without creating anything
#     --once              upload to transfer.sh with one-time-download (gist
#                         backend cannot do true burn-after-read; this routes
#                         to transfer.sh and ignores the launchd path)
#
# Backends:
#   default              gist (auto-delete via launchd)
#   --once               transfer.sh (Max-Downloads: 1, native one-time view)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.claude/share-md"
STATE_FILE="${STATE_DIR}/scheduled.json"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL_PREFIX="com.kiro.share-md"

err() { echo "error: $*" >&2; exit 1; }

# shellcheck source=_with_lock.sh
. "${SCRIPT_DIR}/_with_lock.sh"

mkdir -p "$STATE_DIR" || err "cannot create state dir $STATE_DIR — check permissions"
mkdir -p "$LAUNCH_AGENTS_DIR" || err "cannot create $LAUNCH_AGENTS_DIR — check permissions"
[[ -f "$STATE_FILE" ]] || echo '[]' > "$STATE_FILE"

# parse positional args + flags
file=""
ttl=""
encrypt_flag=0
dry_run_flag=0
once_flag=0
positional=()

while (( $# )); do
  case "$1" in
    --encrypt) encrypt_flag=1; shift ;;
    --dry-run) dry_run_flag=1; shift ;;
    --once)    once_flag=1; shift ;;
    --) shift; positional+=("$@"); break ;;
    -*) err "unknown flag: $1" ;;
    *)  positional+=("$1"); shift ;;
  esac
done
file="${positional[0]:-}"
ttl="${positional[1]:-}"

[[ -n "$file" ]] || err "file path required (arg 1). usage: share.sh <file> <ttl> [--encrypt|--dry-run|--once]"
[[ -n "$ttl" ]] || err "ttl required (arg 2). use 30m, 1h, 24h, 7d, or never"
[[ -f "$file" ]] || err "file not found: $file"

case "$file" in
  *.md|*.markdown) ;;
  *) echo "warn: file is not .md/.markdown — gist will still render text" >&2 ;;
esac

# --once routes to transfer.sh; gist backend can't do native burn-after-read
if [[ "$once_flag" -eq 1 ]]; then
  if [[ "$dry_run_flag" -eq 1 ]]; then
    echo "DRY RUN: would upload $file to transfer.sh with Max-Downloads: 1, ttl ~ $ttl"
    exit 0
  fi
  # transfer.sh max ttl is 14 days; map shorthand to days
  case "$ttl" in
    *d) days="${ttl%d}" ;;
    *h) hours="${ttl%h}"; days=$(( (hours + 23) / 24 )) ;;
    *m) days=1 ;;
    never) days=14 ;;  # transfer.sh hard cap
    *) err "ttl format unsupported for --once. use Nh, Nd, or 'never'" ;;
  esac
  [[ "$days" -ge 1 && "$days" -le 14 ]] || days=14
  exec bash "${SCRIPT_DIR}/_share_transfer_sh.sh" "$file" "$days" --once
fi

command -v gh >/dev/null 2>&1 || err "gh CLI not installed. brew install gh"
gh auth status >/dev/null 2>&1 || err "gh not authenticated. run: gh auth login"
command -v jq >/dev/null 2>&1 || err "jq not installed. brew install jq"

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

# secret scan (advisory — caller decides to abort). skip for --encrypt since
# the file gets encrypted before push and the ciphertext is opaque.
if [[ "$encrypt_flag" -eq 0 ]]; then
  if scan_output=$(bash "${SCRIPT_DIR}/scan_secrets.sh" "$file"); then
    :
  else
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      echo "WARNING: file contains potential secrets:" >&2
      echo "$scan_output" >&2
      echo "" >&2
      echo "abort with Ctrl-C in next 5s, or wait to continue (or rerun with --encrypt)..." >&2
      sleep 5
    else
      err "secret scan failed (exit $rc)"
    fi
  fi
fi

# compute the human-friendly delete time up front so dry-run can show it
if [[ "$target_epoch" != "never" ]]; then
  delete_human="$(date -r "$target_epoch" "+%Y-%m-%d %H:%M %Z")"
else
  delete_human="never"
fi

# --dry-run path: print what would happen, don't create or schedule anything
if [[ "$dry_run_flag" -eq 1 ]]; then
  filename=$(basename "$file")
  filename_enc=$(printf '%s' "$filename" | jq -sRr @uri)
  cat <<DRYOUT
DRY RUN — nothing was created or scheduled.

Would create secret gist:
  Filename:   $filename
  TTL:        $ttl
  Delete at:  $delete_human
  Encrypt:    $([[ "$encrypt_flag" -eq 1 ]] && echo "yes (passphrase generated)" || echo "no")

Would publish:
  Human URL:  https://gist.github.com/<user>/<gist-id>
  Agent URL:  https://gist.githubusercontent.com/<user>/<gist-id>/raw/${filename_enc}

Run without --dry-run to actually create the gist.
DRYOUT
  exit 0
fi

# encrypt step (if requested) — produce ciphertext file alongside
upload_file="$file"
passphrase=""
if [[ "$encrypt_flag" -eq 1 ]]; then
  command -v openssl >/dev/null 2>&1 || err "openssl required for --encrypt"
  enc_dir=$(mktemp -d "${STATE_DIR}/.encrypt.XXXXXX")
  enc_path="${enc_dir}/$(basename "$file").enc"
  passphrase=$(bash "${SCRIPT_DIR}/_encrypt.sh" "$file" "$enc_path") || err "encryption failed"
  upload_file="$enc_path"
fi

# create secret gist
filename=$(basename "$upload_file")
gist_url=$(gh gist create "$upload_file" --desc "share-md: $(basename "$file")$([[ "$encrypt_flag" -eq 1 ]] && echo " (encrypted)")")
gist_id=$(basename "$gist_url")
[[ -n "$gist_id" ]] || err "failed to create gist"

# clean up tmp ciphertext now that it's uploaded
[[ "$encrypt_flag" -eq 1 ]] && rm -rf "$enc_dir"

# URL-encode filename for the raw URL (handles spaces, unicode, parens, etc.)
filename_enc=$(printf '%s' "$filename" | jq -sRr @uri)
stable_raw="https://gist.githubusercontent.com/$(gh api user --jq .login)/${gist_id}/raw/${filename_enc}"

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

# schedule deletion via launchd
plist_path=""
if [[ "$target_epoch" != "never" ]]; then
  label="${LABEL_PREFIX}.${gist_id}"
  plist_path="${LAUNCH_AGENTS_DIR}/${label}.plist"

  year=$(date -r "$target_epoch" +%Y)
  month=$(date -r "$target_epoch" +%-m)
  day=$(date -r "$target_epoch" +%-d)
  hour=$(date -r "$target_epoch" +%-H)
  minute=$(date -r "$target_epoch" +%-M)

  log_file="${STATE_DIR}/${gist_id}.log"

  esc_script_dir=$(xml_escape "$SCRIPT_DIR")
  esc_plist_path=$(xml_escape "$plist_path")
  esc_log_file=$(xml_escape "$log_file")
  esc_filename=$(xml_escape "$filename")
  esc_home=$(xml_escape "$HOME")

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
    <string>${esc_script_dir}/_launchd_delete.sh</string>
    <string>${gist_id}</string>
    <string>${esc_plist_path}</string>
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
    <string>${esc_home}</string>
    <key>SHARE_MD_FILENAME</key>
    <string>${esc_filename}</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${esc_log_file}</string>
  <key>StandardErrorPath</key>
  <string>${esc_log_file}</string>
</dict>
</plist>
PLIST

  launchctl unload "$plist_path" 2>/dev/null || true
  launchctl load "$plist_path"
fi

# append to state file under exclusive lock (mkdir-atomic)
append_state() {
  local record
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
    --arg encrypted "$encrypt_flag" \
    '{gist_id: $gist_id, gist_url: $gist_url, raw_url: $raw_url, filename: $filename, ttl: $ttl, delete_at: $delete_at, target_epoch: $target_epoch, plist_path: $plist_path, created_at: $created_at, encrypted: ($encrypted == "1")}')

  jq --argjson rec "$record" '. + [$rec]' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}
with_lock append_state || err "failed to update state file"

# output
cat <<OUT
✓ Gist created (secret)

Human URL (rendered):
  $gist_url

Agent URL (raw markdown):
  $stable_raw

Auto-delete: $delete_human
Gist ID: $gist_id
OUT

if [[ "$encrypt_flag" -eq 1 ]]; then
  cat <<ENCOUT

🔐 Encrypted with AES-256-CBC + PBKDF2.

Passphrase (share OUT-OF-BAND, never alongside the URL):
  $passphrase

Recipient decrypts with:
  curl -sL "$stable_raw" | openssl enc -d -aes-256-cbc -pbkdf2 -a -pass pass:'$passphrase'
ENCOUT
fi

cat <<TAIL

Cancel scheduled delete:
  bash ${SCRIPT_DIR}/cancel.sh $gist_id

Delete now:
  bash ${SCRIPT_DIR}/delete_now.sh $gist_id

List all pending:
  bash ${SCRIPT_DIR}/list.sh
TAIL
