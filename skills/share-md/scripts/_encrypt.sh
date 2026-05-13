#!/usr/bin/env bash
# _encrypt.sh - encrypt a markdown file with a randomly generated passphrase
# Usage: _encrypt.sh <input-file> <output-file>
# Stdout: the generated passphrase (caller must capture it!)
#
# Uses AES-256-CBC with PBKDF2 key derivation (openssl defaults). Output is
# base64-encoded so it renders as a normal text blob in a gist.

set -euo pipefail

input="${1:-}"
output="${2:-}"

[[ -n "$input" && -f "$input" ]] || { echo "error: input file required" >&2; exit 1; }
[[ -n "$output" ]] || { echo "error: output path required" >&2; exit 1; }

command -v openssl >/dev/null 2>&1 || { echo "error: openssl not installed" >&2; exit 1; }

# 24 bytes -> 32 chars base64 — strong enough that brute-force is infeasible
# even if the gist URL leaks (unlike the URL itself, which is unguessable but
# not authenticated).
passphrase=$(openssl rand -base64 24)

openssl enc -aes-256-cbc -pbkdf2 -salt -a -in "$input" -out "$output" -pass "pass:${passphrase}"

# emit passphrase on stdout for capture by caller
printf '%s\n' "$passphrase"
