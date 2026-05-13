---
name: share-md
description: Share a markdown file via a private GitHub Gist link with optional auto-delete after a custom TTL. Use this skill whenever the user wants to send/share/give a markdown file or doc to a colleague, teammate, agent, or themselves via a URL — even if they don't say "gist" explicitly. Triggers on phrases like "share this markdown", "send this doc as a link", "give me a shareable URL for this .md", "share with auto-delete", "ephemeral share", "expire in N hours/days", "share so my agent can fetch it", or any request to turn a local markdown file into a fetchable URL with optional expiry.
---

# Share Markdown via Gist with Auto-Delete

Turn a local markdown file into a shareable link backed by a secret GitHub Gist, optionally scheduling automatic deletion after a custom TTL via launchd.

## When to use

Use this skill whenever the user wants any markdown file (`.md`, `.markdown`) made available at a URL — for a teammate, an agent that will fetch it, or themselves on another machine. Always offer the auto-delete option unless the user says otherwise; ephemeral sharing is the safer default for sensitive content.

## What you need first

Before running, confirm:
1. The user provides a path to a markdown file (or content to write to one).
2. `gh` CLI is installed and authenticated. Check with `gh auth status`. If not, stop and tell the user to run `gh auth login`.
3. The TTL the user wants. If they don't specify, ask: "How long should this link live? Examples: `1h`, `24h`, `7d`, or `never` (no auto-delete)."

## The workflow

Run `scripts/share.sh` with the file path and TTL. The script handles everything: creates the secret gist, captures the IDs, schedules the launchd cleanup if a TTL was given, and prints both URLs.

```bash
bash <skill-path>/scripts/share.sh <file-path> <ttl>
```

Example invocations:
- `bash <skill-path>/scripts/share.sh ./notes.md 24h`
- `bash <skill-path>/scripts/share.sh /tmp/spec.md 1h`
- `bash <skill-path>/scripts/share.sh ./readme.md never` (no auto-delete)

The script outputs:
- **Human URL** — `https://gist.github.com/<user>/<id>` (rendered)
- **Agent URL** — `https://gist.githubusercontent.com/<user>/<id>/raw/<file>` (raw markdown)
- **Delete time** — wall-clock UTC + local time when gist will be removed (or `never`)
- **Cancel command** — how the user can cancel the scheduled delete

The script also appends a record to `~/.claude/share-md/scheduled.json` so the user can list/cancel pending deletes later via `scripts/list.sh` and `scripts/cancel.sh`.

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
3. The cancel command, in case they change their mind.
4. A one-line note on which URL to give to a human vs. an agent — humans want the rendered page, agents want the raw URL.

Keep the output tight. The user already knows what they asked for; they just need the URLs and the deadline.

## Safety considerations

- **Always create gists as secret** (`gh gist create` without `--public`). Never make a public gist from this skill — secret URLs are unguessable but a public gist gets indexed by search engines.
- **Refuse to share files that look like they contain secrets**. Before creating the gist, scan the markdown for obvious credential patterns: `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9]{36}`, `sk-[A-Za-z0-9]{20,}`, lines containing `password:`/`api_key:`/`secret:` followed by a non-empty value, or `.env`-style `KEY=value` blocks. If matches found, stop, tell the user what was detected, and ask if they really want to proceed.
- **Tell the user secret gists are still readable by anyone with the URL** — there's no auth gate. If they need real auth, recommend the private-repo + PAT pattern instead (see `references/secure-alternatives.md`).

## Cancel and list

If the user asks "what gists am I sharing right now?" or "cancel that share", use:
- `bash <skill-path>/scripts/list.sh` — show all currently scheduled deletes with countdown
- `bash <skill-path>/scripts/cancel.sh <gist-id>` — cancel the scheduled delete (gist persists)
- `bash <skill-path>/scripts/delete_now.sh <gist-id>` — delete immediately, also unschedules

## Why launchd over `at`

macOS `at` requires `atrun` to be loaded via `sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist` and isn't enabled by default on modern macOS. launchd works out of the box, persists across reboots, and is the platform-native scheduler. The script writes a one-shot `LaunchAgent` plist to `~/Library/LaunchAgents/com.kiro.share-md.<gist-id>.plist` with `StartCalendarInterval` set to the delete time, then loads it. After firing, the plist self-unloads and the script removes it.

## Edge cases

- **File not found** → fail loud, don't create empty gist.
- **`gh` not authenticated** → fail with clear instruction to run `gh auth login`.
- **TTL in the past** → reject, ask for a future time.
- **TTL more than 30 days** → confirm with user; long-lived "ephemeral" links are usually a mistake.
- **User passes a non-`.md` file** → warn but allow if they confirm. Gists render any text; the warning is just to prevent accidents.
