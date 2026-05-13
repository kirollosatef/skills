---
name: share-md
description: Share a markdown file via a private GitHub Gist link with optional auto-delete after a custom TTL, end-to-end encryption, dry-run preview, or one-time burn-after-read via transfer.sh. Use this skill whenever the user wants to send/share/give a markdown file or doc to a colleague, teammate, agent, or themselves via a URL — even if they don't say "gist" explicitly. Triggers on phrases like "share this markdown", "send this doc as a link", "give me a shareable URL for this .md", "share with auto-delete", "ephemeral share", "expire in N hours/days", "share so my agent can fetch it", "encrypt before sharing", "password protect this share", "burn after read", "one-time view", "preview the share without creating it", or any request to turn a local markdown file into a fetchable URL with optional expiry, encryption, or single-use semantics.
compatibility:
  shell: bash
  os: macos
  required:
    - gh (authenticated, gist scope)
    - jq
  optional:
    - openssl (for --encrypt)
    - curl (for --once)
    - cmux (for desktop notification on auto-delete fire)
  features:
    - launchd (for scheduled deletion)
---

# Share Markdown via Gist with Auto-Delete

Turn a local markdown file into a shareable link backed by a secret GitHub Gist, optionally scheduling automatic deletion after a custom TTL via launchd. Supports end-to-end encryption (`--encrypt`), preview mode (`--dry-run`), and one-time-download via transfer.sh (`--once`).

## When to use

Use this skill whenever the user wants any markdown file (`.md`, `.markdown`) made available at a URL — for a teammate, an agent that will fetch it, or themselves on another machine. Always offer the auto-delete option unless the user says otherwise; ephemeral sharing is the safer default for sensitive content.

## What you need first

Before running, confirm:
1. The user provides a path to a markdown file (or content to write to one).
2. `gh` CLI is installed and authenticated. Check with `gh auth status`. If not, stop and tell the user to run `gh auth login`.
3. The TTL the user wants. If they don't specify, ask: "How long should this link live? Examples: `1h`, `24h`, `7d`, or `never` (no auto-delete)."
4. Whether the content is sensitive enough to warrant `--encrypt`. Default is no; offer it when the user mentions "confidential", "sensitive", "password protect", "encrypt", or shares anything resembling credentials, customer data, internal-only specs.

## The workflow

Run `scripts/share.sh` with the file path, TTL, and optional flags. The script handles everything: creates the secret gist, captures the IDs, schedules the launchd cleanup if a TTL was given, and prints both URLs.

```bash
bash <skill-path>/scripts/share.sh <file-path> <ttl> [flags]
```

**Examples:**
- `bash <skill-path>/scripts/share.sh ./notes.md 24h` — basic ephemeral share
- `bash <skill-path>/scripts/share.sh /tmp/spec.md 1h` — short-lived link
- `bash <skill-path>/scripts/share.sh ./readme.md never` — no auto-delete
- `bash <skill-path>/scripts/share.sh ./roadmap.md 7d --encrypt` — encrypted, share passphrase out-of-band
- `bash <skill-path>/scripts/share.sh ./preview.md 24h --dry-run` — show URLs/expiry without creating gist
- `bash <skill-path>/scripts/share.sh ./secret.md 1d --once` — one-time view (transfer.sh backend)

## Flags

### `--encrypt`
Encrypt the file with a randomly generated passphrase before pushing. The gist contents become opaque AES-256-CBC ciphertext (PBKDF2-derived key, base64-armored). Even if the URL leaks, an attacker without the passphrase sees gibberish. Output includes the decrypt command for the recipient.

**Important:** the passphrase prints to stdout. Tell the user to share it OUT-OF-BAND (different channel from the URL), never alongside the link.

### `--dry-run`
Print exactly what would happen — TTL, delete time, URL shape, encryption status — without creating a gist or scheduling launchd. Use when the user wants to confirm before committing.

### `--once`
Routes to `transfer.sh` instead of GitHub Gist. transfer.sh natively supports `Max-Downloads: 1`: the URL returns 404 after the first fetch. Gist backend cannot do true burn-after-read; this is the only one-time-view path.

TTL semantics for `--once`: mapped to days (1-14, transfer.sh max). `never` becomes 14 days.

## TTL format

Accept these forms (parse with `scripts/parse_ttl.sh`):
- `30m`, `45m` — minutes
- `1h`, `24h` — hours
- `1d`, `7d` — days
- `never` — skip scheduling, gist persists until manually deleted

Reject anything else and ask the user to re-specify. Don't silently default — getting the TTL wrong means either the gist outlives its purpose or vanishes too soon.

## Reporting back to the user

After the script succeeds, report:
1. Both URLs (human + agent), each on its own line in a code block so they're easy to click and copy.
2. The delete time in human-friendly form ("expires in 24h at 2026-05-14 11:47 PDT").
3. If `--encrypt` was used: the passphrase, called out clearly, with a reminder to share it on a different channel.
4. The cancel command, in case they change their mind.
5. A one-line note on which URL to give to a human vs. an agent — humans want the rendered page, agents want the raw URL.

Keep the output tight. The user already knows what they asked for; they just need the URLs and the deadline.

## Safety considerations

- **Always create gists as secret** (`gh gist create` without `--public`). Never make a public gist from this skill — secret URLs are unguessable but a public gist gets indexed by search engines.
- **Pre-share secret scan.** Before pushing (unless `--encrypt`), the file is scanned for credential patterns: `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9]{36}`, `sk-[A-Za-z0-9]{20,}`, lines containing `password:`/`api_key:`/`secret:`, or `.env`-style `KEY=value` blocks. If matches found, stop, surface the matches, and ask whether to abort, redact, or rerun with `--encrypt`.
- **Tell the user secret gists are still URL-leak-prone** — there's no auth gate. For real auth, recommend `--encrypt` (this skill) or the private-repo + PAT pattern (see `references/secure-alternatives.md`).
- **`--encrypt` skips the secret scan** — the encrypted blob is opaque, so scanning is meaningless. The encryption is the protection.

## Cancel and list

If the user asks "what gists am I sharing right now?" or "cancel that share", use:
- `bash <skill-path>/scripts/list.sh` — show all currently scheduled deletes with live countdown
- `bash <skill-path>/scripts/cancel.sh <gist-id>` — cancel the scheduled delete (gist persists)
- `bash <skill-path>/scripts/delete_now.sh <gist-id>` — delete immediately, also unschedules

## Why launchd over `at`

macOS `at` requires `atrun` to be loaded via `sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist` and isn't enabled by default on modern macOS. launchd works out of the box, persists across reboots, and is the platform-native scheduler. The script writes a one-shot `LaunchAgent` plist to `~/Library/LaunchAgents/com.kiro.share-md.<gist-id>.plist` with `StartCalendarInterval` set to the delete time, then loads it. After firing, the plist self-removes and the launchd job unloads itself.

## Concurrency

Multiple share/cancel/delete operations are safe to run in parallel — `scripts/_with_lock.sh` provides an mkdir-atomic lock around every read-modify-write of `scheduled.json`. No `flock` dependency required (which macOS lacks by default). Stale locks (>30s) are reclaimed automatically in case a previous holder crashed.

## State file format

`~/.claude/share-md/scheduled.json` is a JSON array of records:

```json
[
  {
    "gist_id": "abc123...",
    "gist_url": "https://gist.github.com/user/abc123...",
    "raw_url": "https://gist.githubusercontent.com/user/abc123.../raw/notes.md",
    "filename": "notes.md",
    "ttl": "24h",
    "delete_at": "2026-05-14 11:47 EEST",
    "target_epoch": "1779180420",
    "plist_path": "/Users/.../Library/LaunchAgents/com.kiro.share-md.abc123.plist",
    "created_at": "2026-05-13T08:47:00Z",
    "encrypted": false
  }
]
```

Failure mode: if `gh gist delete` fails (auth, network), state is **kept** so the user can retry. The state file represents intent + reality, not just intent.

## Edge cases

- **File not found** → fail loud, don't create empty gist.
- **`gh` not authenticated** → fail with clear instruction to run `gh auth login`.
- **TTL in the past** → reject, ask for a future time.
- **TTL more than 30 days** → confirm with user; long-lived "ephemeral" links are usually a mistake.
- **User passes a non-`.md` file** → warn but allow. Gists render any text.
- **File >1 MB** → secret scan refuses (would hang grep); user must split or share differently.
- **Filename with spaces / unicode** → URL-encoded automatically in raw URL.
- **Concurrent shares** → file lock serializes; no corruption.
- **`gh` delete fails at auto-delete time** → state retained, gist still alive, no silent drift; user can run `delete_now.sh` manually.
