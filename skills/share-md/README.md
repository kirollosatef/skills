# share-md

> Turn any markdown file into a shareable link with optional auto-delete, end-to-end encryption, or one-time burn-after-read.

[![Install](https://img.shields.io/badge/Install-npx%20skills%20add%20kirollosatef%2Fskills%40share--md-blue)](https://skills.sh/kirollosatef/skills/share-md)
[![Compatible](https://img.shields.io/badge/Compatible-Claude%20Code%20%7C%20Cursor%20%7C%20Codex%20%7C%20%2B37%20more-green)](https://skills.sh)
[![macOS](https://img.shields.io/badge/macOS-required%20for%20auto--delete-lightgrey)](https://en.wikipedia.org/wiki/Launchd)

A Claude Code / Cursor / Codex skill that lets your AI agent share markdown files as URLs — to a colleague, a different machine, or another agent — with smart safety defaults baked in.

---

## Install

```bash
npx skills add kirollosatef/skills@share-md -g -y
```

Or via the bundled installer (Claude Code only):

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- share-md
```

**Prereqs:** `gh` (authenticated, gist scope), `jq`, macOS (for auto-delete via launchd). Optional: `openssl` (for `--encrypt`), `curl` (for `--once`).

```bash
brew install gh jq
gh auth login
```

---

## Usage (talk to your agent)

```
Share /tmp/notes.md with my teammate, expires in 1 hour
```

```
Send this spec doc to my agent on the other machine — no expiry, I'll clean up later
```

```
Share this confidential roadmap, encrypt it so the link alone is useless
```

```
Show me what would happen if I shared this — don't actually create it yet
```

```
What gists am I currently sharing?
```

```
Cancel that share but keep the gist alive
```

```
Delete that gist now
```

The agent picks the right script + flags from natural language.

---

## Direct CLI usage

If you want to skip the agent and call the scripts yourself:

```bash
SKILL=~/.claude/skills/share-md/scripts

# basic share with TTL
bash $SKILL/share.sh ./notes.md 1h
bash $SKILL/share.sh ./notes.md 24h
bash $SKILL/share.sh ./notes.md 7d
bash $SKILL/share.sh ./notes.md never

# encrypted share — passphrase printed, share OUT-OF-BAND
bash $SKILL/share.sh ./roadmap.md 7d --encrypt

# preview without creating
bash $SKILL/share.sh ./preview.md 24h --dry-run

# one-time view (transfer.sh backend)
bash $SKILL/share.sh ./secret.md 1d --once

# manage
bash $SKILL/list.sh                        # show all active shares with countdown
bash $SKILL/cancel.sh <gist-id>            # cancel scheduled delete (gist persists)
bash $SKILL/delete_now.sh <gist-id>        # delete immediately
```

---

## Features

### Auto-delete via launchd

Specify a TTL (`30m`, `1h`, `24h`, `7d`, `never`) — the script writes a `LaunchAgent` plist to `~/Library/LaunchAgents/` that fires at the exact wall-clock time and cleans up after itself.

Why launchd over `at`: `at` requires `atrun` to be loaded via sudo on modern macOS. launchd works out of the box and persists across reboots.

### `--encrypt` — AES-256-CBC + PBKDF2

When the URL alone shouldn't be enough:

```bash
bash share.sh ./confidential.md 7d --encrypt
```

The file is encrypted with a randomly generated 32-character passphrase before pushing. The gist contents become opaque ciphertext (base64-armored). The passphrase prints to stdout with an explicit "share OUT-OF-BAND" warning. The recipient runs:

```bash
curl -sL <raw-url> | openssl enc -d -aes-256-cbc -pbkdf2 -a -pass pass:'<passphrase>'
```

### `--dry-run`

Preview exactly what would happen — TTL, delete time, URL shape, encryption status — without creating a gist or scheduling launchd. Use when you want to confirm before committing.

### `--once` — burn-after-read

Routes to [transfer.sh](https://transfer.sh) with `Max-Downloads: 1`. URL returns 404 after the first fetch. Gist backend cannot do native one-time-view; this is the only path that supports it.

### Pre-share secret scan

Before pushing (unless `--encrypt` is used), the file is scanned for credential patterns:

- AWS access keys (`AKIA[0-9A-Z]{16}`)
- GitHub PATs (classic + fine-grained)
- OpenAI / Anthropic / Slack tokens
- Generic `password:`, `api_key:`, `secret:`, `Bearer ...` patterns
- `-----BEGIN PRIVATE KEY-----` blocks

If matches found, the script halts, surfaces the matched lines, and offers three remediations: abort, redact manually, or rerun with `--encrypt`.

### Concurrency-safe state

Multiple `share.sh` runs in parallel are safe — the script uses an `mkdir`-atomic file lock around every read-modify-write of `~/.claude/share-md/scheduled.json`. No `flock` dependency required (which macOS lacks by default). Stale locks (>30s) are reclaimed automatically.

### cmux desktop notification

If [`cmux`](https://github.com/cmux/cmux) is installed, the auto-delete event fires a desktop toast so you know your gist disappeared. No-op if cmux is missing.

---

## Output format

```
Gist created (secret)

Human URL (rendered):
  https://gist.github.com/<user>/<id>

Agent URL (raw markdown):
  https://gist.githubusercontent.com/<user>/<id>/raw/<file>

Auto-delete: 2026-05-14 11:47 EEST
Gist ID: abc123...

Cancel scheduled delete:
  bash ~/.claude/skills/share-md/scripts/cancel.sh abc123...

Delete now:
  bash ~/.claude/skills/share-md/scripts/delete_now.sh abc123...

List all pending:
  bash ~/.claude/skills/share-md/scripts/list.sh
```

When `--encrypt` is used, an additional section prints the passphrase + decrypt command.

---

## How it stays in sync

State lives at `~/.claude/share-md/scheduled.json`:

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

Atomicity guarantee: the state file is updated only when the underlying operation succeeds. If `gh gist delete` fails (network, auth), state is **kept** so you can retry — no silent drift between intent and reality.

---

## Security model

| Threat | Default protection | `--encrypt` protection |
|--------|-------------------|------------------------|
| Search engine indexing | Secret gist URL is not indexed | Same |
| Accidental URL sharing | Unguessable URL (~256 bits entropy) | URL alone reveals nothing without passphrase |
| Recipient forwards URL | Anyone with URL reads | Only those with passphrase read |
| Gist outlives its purpose | Auto-delete via launchd | Same |
| Credentials in file | Pre-share secret scan halts | Scan skipped (blob is opaque); user responsible |

For higher-security needs (real auth, audit logging), see [`references/secure-alternatives.md`](references/secure-alternatives.md) which documents private repo + PAT, R2 presigned URLs, and Cloudflare Worker patterns.

---

## Edge cases handled

- **Filename with spaces / unicode** → URL-encoded automatically
- **TTL in the past** → rejected with clear error
- **TTL > 30 days** → warns "long-lived ephemeral usually mistake" but allows
- **File >1 MB** → secret scan refuses (would hang grep)
- **Concurrent shares** → file lock serializes
- **`gh` delete fails at auto-delete time** → state retained, user can retry
- **State file corruption** → `list.sh` flags as `INVALID` instead of crashing
- **`gh` auth missing** → fails with clear "run gh auth login" message at every entry point

---

## Eval results

Iteration-2 benchmark vs iteration-1 baseline (10 subagent runs, 5 evals × 2 versions):

| Eval | v2 | v1 | Result |
|------|----|----|--------|
| 1h TTL share | ✓ | ✓ | tie |
| Permanent share | ✓ | ✓ | tie |
| File with secrets | ✓ stops + offers `--encrypt` | ✓ stops only | v2 wins |
| Encrypt confidential | ✓ uses `--encrypt` | ✗ pushed plaintext | **v2 wins (security)** |
| Dry-run preview | ✓ uses `--dry-run` | ✗ no flag, refused | **v2 wins (capability)** |

Full benchmark: [iteration-2 results](../share-md-workspace/iteration-2/benchmark.md).

---

## Roadmap

Future iterations may add:

- Multi-file / dir share (`share.sh dir/`)
- Update-in-place (`--update <gist-id>`)
- Cloudflare Worker backend (true read receipts + one-time view that always works)
- Linux support via systemd timer
- GitHub Actions CI (shellcheck + e2e on every push)
- Auto-deliver to Slack / email
- QR code in terminal output

[Open an issue](https://github.com/kirollosatef/skills/issues) to vote or request features.

---

## License

[MIT](../../LICENSE)
