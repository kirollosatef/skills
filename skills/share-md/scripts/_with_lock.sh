#!/usr/bin/env bash
# _with_lock.sh - run a callable while holding an exclusive lock on the state dir
# Usage: source this file, then call `with_lock cmd args...`
#
# Uses mkdir atomicity (POSIX-portable, no flock dependency). Stale locks
# (older than 30s) are reclaimed automatically — protects against a previous
# process crashing while holding the lock.

STATE_DIR="${HOME}/.claude/share-md"
LOCK_DIR="${STATE_DIR}/.lockd"
LOCK_TIMEOUT_TRIES=50      # 50 × 100ms = 5s
LOCK_STALE_SECONDS=30

with_lock() {
  mkdir -p "$STATE_DIR" || return 1

  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [[ -d "$LOCK_DIR" ]]; then
      local age
      age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0) ))
      if [[ "$age" -gt "$LOCK_STALE_SECONDS" ]]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
        continue
      fi
    fi

    tries=$((tries + 1))
    if [[ "$tries" -ge "$LOCK_TIMEOUT_TRIES" ]]; then
      echo "error: could not acquire share-md state lock after $((LOCK_TIMEOUT_TRIES / 10))s" >&2
      return 1
    fi
    sleep 0.1
  done

  local rc=0
  "$@" || rc=$?
  rmdir "$LOCK_DIR" 2>/dev/null || true
  return "$rc"
}
