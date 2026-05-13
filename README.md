# skills

Personal collection of Claude Code skills by [@kirollosatef](https://github.com/kirollosatef). Drop-in capabilities your Claude agent can invoke automatically.

Repo: [github.com/kirollosatef/skills](https://github.com/kirollosatef/skills)

## Install

### One-liner (recommended)

Install a single skill:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- share-md
```

Install multiple at once:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- share-md other-skill
```

Install everything:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- --all
```

List available skills:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- --list
```

Skills land in `~/.claude/skills/<name>/`. Restart Claude Code (or open a new session) to pick them up.

### Manual install

```bash
git clone https://github.com/kirollosatef/skills.git
mkdir -p ~/.claude/skills
cp -R skills/skills/share-md ~/.claude/skills/
chmod +x ~/.claude/skills/share-md/scripts/*.sh
```

Or symlink for live development:

```bash
ln -s "$PWD/skills/skills/share-md" ~/.claude/skills/share-md
```

## Available skills

| Skill | What it does | Triggers on |
|-------|--------------|-------------|
| [`share-md`](skills/share-md/) | Share a `.md` file via secret GitHub Gist URL with optional auto-delete (custom TTL via launchd), end-to-end encryption (`--encrypt`), preview mode (`--dry-run`), or one-time burn-after-read via transfer.sh (`--once`). Returns separate human-rendered + agent-raw URLs. | "share this markdown", "send doc as link", "give me a URL my agent can fetch", "share with auto-delete", "ephemeral share", "encrypt before sharing", "one-time view", "preview the share" |

## Adding your own skill

1. Create `skills/<your-skill-name>/SKILL.md` with frontmatter (`name`, `description`).
2. Drop scripts in `skills/<your-skill-name>/scripts/`, references in `references/`, assets in `assets/`.
3. Open a PR — or fork this repo and use it as your own skills index.

See [Anthropic's skill docs](https://docs.claude.com/en/docs/claude-code/skills) for the full skill format.

## Updating

Re-running the install command overwrites the existing copy with the latest version.

## Uninstall

```bash
rm -rf ~/.claude/skills/<skill-name>
```

For `share-md` specifically, also clean up any pending launchd jobs:

```bash
launchctl list | grep com.kiro.share-md | awk '{print $3}' | while read label; do
  launchctl unload ~/Library/LaunchAgents/${label}.plist 2>/dev/null
  rm -f ~/Library/LaunchAgents/${label}.plist
done
rm -rf ~/.claude/share-md
```

## License

MIT
