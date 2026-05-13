# skills

> Drop-in capabilities your Claude / Cursor / Codex / Cline agent can invoke automatically.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![skills.sh](https://img.shields.io/badge/skills.sh-kirollosatef%2Fskills-blue)](https://skills.sh/kirollosatef/skills)
[![Compatible with 40+ agents](https://img.shields.io/badge/Compatible-Claude%20Code%20%7C%20Cursor%20%7C%20Codex%20%7C%20Cline%20%7C%20%2B36%20more-green)](https://skills.sh)

A curated, eval-tested collection of agent skills by [@kirollosatef](https://github.com/kirollosatef). Install once, use anywhere — every skill works across [40+ AI agents](https://skills.sh) thanks to the universal `SKILL.md` format.

---

## Why skills?

Modern AI agents are powerful but generic. Skills package **procedural knowledge** — how to do a specific job correctly, safely, and reliably — so your agent stops reinventing the wheel every conversation.

This repo is opinionated, security-focused, and **test-backed**: every skill ships with subagent eval results comparing performance against a no-skill baseline.

---

## Quickstart

**One command, one skill:**

```bash
npx skills add kirollosatef/skills@share-md -g -y
```

Or via curl + the bundled installer:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- share-md
```

Restart your agent (Claude Code, Cursor, etc.) and it will auto-discover the skill.

**Then just talk to your agent:**

> "Share `~/notes.md` with my colleague, expires in 1 hour"

Agent invokes `share-md` automatically, returns a secret URL with auto-delete scheduled.

---

## Available skills

| Skill | One-liner | Key features |
|-------|-----------|--------------|
| [**`share-md`**](skills/share-md/) | Share a markdown file via private GitHub Gist URL with optional auto-delete | TTL via launchd · `--encrypt` (AES-256) · `--once` (burn-after-read) · `--dry-run` · pre-share secret scan |

Full skill catalog also browsable on [skills.sh/kirollosatef/skills](https://skills.sh/kirollosatef/skills).

---

## Try it (copy-paste)

After installing `share-md`, ask your agent any of these:

```
Share /tmp/notes.md with my teammate, link expires in 1 hour
```

```
Send this spec doc to my other agent — needs to fetch via curl, no expiry
```

```
Share this confidential roadmap, encrypt it so the link alone is useless
```

```
Show me what would happen if I shared this file with a 24h TTL — don't actually create it yet
```

```
What gists am I currently sharing?
```

```
Cancel that share but keep the gist alive
```

The agent picks the right `share.sh` flags from natural language.

---

## How it works

```
┌─────────────────┐
│ Your AI agent   │  reads SKILL.md frontmatter (always in context)
│ (Claude/Cursor) │
└────────┬────────┘
         │ user request matches description triggers
         ▼
┌─────────────────┐
│ SKILL.md body   │  loaded only when relevant
│ (workflow guide)│
└────────┬────────┘
         │ tells agent which scripts to run
         ▼
┌─────────────────┐      ┌─────────────────┐
│ scripts/*.sh    │ ───▶ │ Real APIs       │
│ (deterministic) │      │ gh, openssl,    │
└─────────────────┘      │ launchd, curl   │
                         └─────────────────┘
```

**Three-layer progressive disclosure** (per [Anthropic best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)):

1. **Metadata** (`name` + `description`) — always in context, ~100 tokens
2. **SKILL.md body** — loaded when description matches user intent
3. **Bundled scripts/refs** — invoked or read on-demand, zero context cost

---

## Compatibility matrix

| Agent | Status | Install path |
|-------|--------|--------------|
| Claude Code | ✓ Native | `~/.claude/skills/` |
| Cursor | ✓ Universal symlink | auto via `npx skills add` |
| Codex CLI | ✓ Universal symlink | auto via `npx skills add` |
| Cline | ✓ Universal symlink | auto via `npx skills add` |
| Windsurf, Gemini, Copilot, Antigravity, +33 more | ✓ Universal symlink | auto via `npx skills add` |

Full list: [skills.sh agents](https://skills.sh/agent).

---

## Install methods compared

| Method | Best for | Updates | Multi-agent |
|--------|----------|---------|-------------|
| `npx skills add owner/repo@skill` | Most users | Re-run command | Yes (40+ agents) |
| `curl ... \| bash` | Claude Code only | Re-run command | No (Claude Code only) |
| `git clone` + symlink | Skill authors / hackers | `git pull` | Manual |

---

## Add your own skill

```
skills/<your-skill-name>/
├── SKILL.md          required: YAML frontmatter + workflow body
├── README.md         optional: rich page for skills.sh
├── scripts/          optional: executable helpers
├── references/       optional: long-form docs (loaded on-demand)
└── evals/evals.json  recommended: 3+ test prompts
```

**Minimal `SKILL.md`:**

```markdown
---
name: my-skill
description: One-paragraph description that includes both what the skill does AND specific phrases the user might say to trigger it.
---

# My Skill

How to do the thing. Reference scripts/ when deterministic logic is needed.
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full walkthrough including eval setup, naming conventions, and PR rules.

---

## Updating

Re-running the install command pulls the latest version and overwrites the local copy:

```bash
npx skills add kirollosatef/skills@share-md -g -y
```

Or for the curl installer:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- share-md
```

The `npx skills update` command can refresh all installed skills at once.

---

## Uninstall

```bash
rm -rf ~/.claude/skills/<skill-name>
```

For `share-md` specifically, also unschedule any pending auto-delete jobs:

```bash
launchctl list | grep com.kiro.share-md | awk '{print $3}' | while read label; do
  launchctl bootout "gui/$UID/$label" 2>/dev/null
  rm -f ~/Library/LaunchAgents/${label}.plist
done
rm -rf ~/.claude/share-md
```

---

## FAQ

**Q: Do I need a GitHub account?**
For `share-md`: yes — `gh auth login`. For other skills: depends.

**Q: macOS only?**
The current `share-md` skill uses launchd, so yes for the auto-delete feature. Linux support via systemd timer is planned (see [iteration-3 roadmap](skills/share-md-workspace/iteration-2/benchmark.md#recommendations-for-iteration-3)).

**Q: Will this leak my data?**
- Secret gists are unguessable but **not** authenticated. Use `--encrypt` for sensitive content.
- All scripts are open source — read them before installing.
- No telemetry from these skills directly. The `npx skills` CLI tracks anonymous install counts only (see [skills.sh privacy](https://skills.sh/docs/faq)).

**Q: How do I report a bug or request a feature?**
[Open an issue](https://github.com/kirollosatef/skills/issues).

**Q: Can I fork and use this as my own skills repo?**
Yes — MIT licensed. Just update the `kirollosatef/skills` references in `install.sh` and `README.md`.

**Q: How are skills discovered by my agent?**
Each agent scans its own skills directory at startup. The `name` and `description` from every skill's YAML frontmatter is loaded into context. When you make a request that matches a description, the agent reads that skill's body and follows the workflow.

---

## Security

These skills run with full agent permissions — they execute shell scripts, write files, call external APIs. **Always review a skill before installing.** Specific safety properties of skills in this repo:

- **`share-md`** scans for credential patterns (AWS, GitHub, OpenAI, Anthropic keys; password/api_key fields) before publishing. `--encrypt` provides AES-256-CBC + PBKDF2 protection. State file is locked against concurrent corruption.

To report a security issue, please open an issue on [GitHub](https://github.com/kirollosatef/skills/issues) or contact the maintainer directly.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## License

[MIT](LICENSE) © Kirollos Atef
