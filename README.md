# claude-skills

Personal collection of Claude Code skills by [@kirollosatef](https://github.com/kirollosatef). Drop-in capabilities your Claude agent can invoke automatically.

## Install

### One-liner (recommended)

Install a single skill:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/claude-skills/main/install.sh | bash -s -- share-markdown
```

Install multiple at once:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/claude-skills/main/install.sh | bash -s -- share-markdown other-skill
```

Install everything:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/claude-skills/main/install.sh | bash -s -- --all
```

List available skills:

```bash
curl -sL https://raw.githubusercontent.com/kirollosatef/claude-skills/main/install.sh | bash -s -- --list
```

Skills land in `~/.claude/skills/<name>/`. Restart Claude Code (or open a new session) to pick them up.

### Manual install

```bash
git clone https://github.com/kirollosatef/claude-skills.git
mkdir -p ~/.claude/skills
cp -R claude-skills/skills/share-markdown ~/.claude/skills/
chmod +x ~/.claude/skills/share-markdown/scripts/*.sh
```

Or symlink for live development:

```bash
ln -s "$PWD/claude-skills/skills/share-markdown" ~/.claude/skills/share-markdown
```

## Available skills

| Skill | What it does | Triggers on |
|-------|--------------|-------------|
| [`share-markdown`](skills/share-markdown/) | Share a `.md` file via secret GitHub Gist URL with optional auto-delete after a custom TTL (e.g. `1h`, `24h`, `7d`). Returns separate human-rendered + agent-raw URLs. | "share this markdown", "send doc as link", "give me a URL my agent can fetch", "share with auto-delete", "ephemeral share" |

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

For `share-markdown` specifically, also clean up any pending launchd jobs:

```bash
launchctl list | grep com.kiro.share-markdown | awk '{print $3}' | while read label; do
  launchctl unload ~/Library/LaunchAgents/${label}.plist 2>/dev/null
  rm -f ~/Library/LaunchAgents/${label}.plist
done
rm -rf ~/.claude/share-markdown
```

## License

MIT
