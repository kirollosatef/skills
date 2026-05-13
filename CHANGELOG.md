# Changelog

All notable changes to this skills collection are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned (iteration-3)
- GitHub Actions CI: shellcheck + e2e tests on every push
- Cloudflare Worker backend for `share-md` (true read receipts + reliable one-time view)
- Linux support via systemd timer detection
- Multi-file / dir share (`share.sh dir/`)
- Update-in-place (`--update <gist-id>`)
- Auto-deliver to Slack / email (`--to @sarah`)
- QR code in terminal output
- Test on Sonnet 4.6 + Haiku 4.5 (currently Opus-only verified)
- Description optimization run for trigger accuracy

---

## [0.2.0] — 2026-05-13

Iteration-2: P0 audit fixes + P1 features for `share-md`.

### Added
- `share-md`: `--encrypt` flag (AES-256-CBC + PBKDF2 + base64 armor via openssl). Gist contents become opaque ciphertext; passphrase printed with explicit "share OUT-OF-BAND" warning; recipient decrypts with single `curl | openssl` pipe. New `scripts/_encrypt.sh` helper.
- `share-md`: `--dry-run` flag. Prints would-be URLs, expiry, encryption status without creating gist or scheduling launchd.
- `share-md`: `--once` flag. Routes to transfer.sh with `Max-Downloads: 1` (true burn-after-read). Gist backend cannot do native one-time-view; this is the only path.
- `share-md`: `compatibility:` field in SKILL.md frontmatter declaring required (gh, jq) and optional (openssl, curl, cmux) deps + os: macos + feature: launchd. Anthropic best-practice for skill discoverability and pre-flight.
- `share-md`: cmux desktop notification on auto-delete fire (no-op if cmux not installed). Surfaces auto-delete event so it's not silent.
- `share-md`: `scripts/_with_lock.sh` helper providing mkdir-atomic file lock (no flock dep on macOS) used by share/cancel/delete_now/_launchd_delete to serialize state writes.

### Fixed
- `share-md`: filename with spaces in stable_raw URL not URL-encoded (was breaking `curl` fetch). Fixed via `jq -sRr @uri`.
- `share-md`: `gh gist delete` failure was masked by `|| true`, cleaning state even when gist still alive (state/reality drift). Now: only prune state on successful deletion; failed deletes retain state for retry.
- `share-md`: race condition on `scheduled.json` — concurrent share.sh runs could corrupt state. Now serialized via mkdir-atomic lock.
- `share-md`: corrupted `target_epoch` in state file caused silent `null` from `jq tonumber`, breaking arithmetic and producing garbled `list.sh` output. Now validated and surfaced as `INVALID`.
- `share-md`: `cancel.sh` and `delete_now.sh` called `gh api user` without first checking gh auth, producing confusing GitHub errors. Now: pre-flight `gh auth status` with helpful message.
- `share-md`: `mkdir -p` lacked error checking — silent failures produced confusing downstream errors. Now: explicit error with remediation.
- `share-md`: plist heredoc used unescaped variables; if `SCRIPT_DIR` or `log_file` contained `<`, `>`, or `&`, plist became invalid XML and launchctl failed. Now: XML-escaped via sed.
- `share-md`: `scan_secrets.sh` had no file size limit — large or binary files could hang grep or exhaust memory. Now: refuses files >1 MB with clear error.
- `share-md`: `list.sh` used `IFS=$'\t'` parsing that broke if filename contained tabs/newlines. Now: base64-encoded records for safe round-tripping.

### Changed
- Repo: rewrote root `README.md` with quickstart, examples, compatibility matrix, FAQ, security section.
- Repo: added per-skill `README.md` for `share-md` so skills.sh detail page renders rich content.
- Repo: added `CONTRIBUTING.md` with skill quality bar, structure template, eval expectations, PR workflow.

---

## [0.1.0] — 2026-05-13

Initial release.

### Added
- `share-md` skill — share a markdown file via secret GitHub Gist URL with optional auto-delete after a custom TTL via launchd.
  - `share.sh` — main entry, takes `<file> <ttl>` (30m / 1h / 24h / 7d / never)
  - `parse_ttl.sh` — TTL string → epoch
  - `scan_secrets.sh` — pre-share credential scan (AWS, GitHub, OpenAI, Anthropic, Slack tokens; password/api_key fields; private key blocks; bearer tokens)
  - `_launchd_delete.sh` — launchd callback, deletes gist + cleans state
  - `cancel.sh` — cancel scheduled deletion (gist persists)
  - `delete_now.sh` — immediate delete + unschedule
  - `list.sh` — show pending shares with countdown
- `references/secure-alternatives.md` — patterns for higher-security needs (private repo + PAT, R2 presigned, Cloudflare Worker)
- `evals/evals.json` — 3 eval prompts (1h TTL, permanent share, secrets warning)
- `install.sh` — one-liner curl installer with `--all` / `--list` / specific-skill modes
- `README.md`, `LICENSE` (MIT), `.gitignore`
- Initial iteration-1 eval cycle (3 evals × {with_skill, without_skill}) demonstrating skill correctness vs unprompted baseline

### Repo
- Public on GitHub at [`kirollosatef/skills`](https://github.com/kirollosatef/skills)
- Listed on [`skills.sh/kirollosatef/skills`](https://skills.sh/kirollosatef/skills)
- Installable via `npx skills add kirollosatef/skills@share-md` (universal, 40+ agents) or `curl ... install.sh | bash` (Claude Code)
