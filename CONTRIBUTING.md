# Contributing

Thanks for considering a contribution. This repo is a curated, eval-tested collection — quality over quantity. Read this guide before opening a PR or filing an issue.

---

## What kinds of contributions are welcome

- **New skills** that solve a real, repeated problem and pass the bar below
- **Bug fixes** for existing skills (with a regression test in the eval set)
- **Doc improvements** (clarity, typos, missing examples)
- **Cross-platform support** (Linux/Windows variants of macOS-only skills)
- **Performance improvements** (benchmarked, not vibes-based)

## What is out of scope

- Skills that wrap a single API call without added safety/UX value
- Skills that duplicate existing well-rated skills on [skills.sh](https://skills.sh)
- Anything requiring telemetry, auth servers, or external infrastructure the user must run

---

## Bar for new skills

Before opening a PR with a new skill, verify:

- [ ] **Solves a real, repeated problem.** Not a one-off script.
- [ ] **`SKILL.md` follows [Anthropic best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)**:
  - Specific `description` with both *what* + *when to use* (trigger phrases)
  - Body under 500 lines
  - References (long docs) split into `references/*.md`, one level deep
  - No time-sensitive info ("after Q3 2026 use new API")
  - Consistent terminology
- [ ] **`compatibility:` field** declares all required + optional dependencies
- [ ] **At least 3 evals** in `evals/evals.json` covering happy path + edge cases + a security-relevant scenario
- [ ] **Scripts handle errors explicitly** (no silent `|| true` masking failures)
- [ ] **Pre-share secret scan** if the skill publishes content anywhere
- [ ] **`README.md`** for the skill (rich content for skills.sh detail page)
- [ ] **Tested with at least 2 model tiers** (Sonnet + Opus, ideally + Haiku)

---

## Skill structure

```
skills/<your-skill>/
├── SKILL.md          required: YAML frontmatter + agent workflow
├── README.md         recommended: rich page for skills.sh
├── scripts/          optional: deterministic helpers
│   ├── _helper.sh    convention: leading underscore = "internal, not user-facing"
│   └── main.sh
├── references/       optional: long docs loaded on-demand
│   └── advanced.md
├── assets/           optional: templates, fonts, icons used in output
└── evals/
    └── evals.json    recommended: subagent test prompts
```

### `SKILL.md` template

```markdown
---
name: my-skill
description: One paragraph that includes WHAT the skill does AND specific trigger phrases users might say. Be specific. Include uncommon use cases. Anthropic recommends being a little "pushy" — say "Use this skill whenever the user mentions X, Y, or Z" rather than "May be useful for X."
compatibility:
  shell: bash
  os: macos
  required:
    - dep1
    - dep2
  optional:
    - dep3
  features:
    - feature-name
---

# My Skill Title

One-sentence description.

## When to use

Concrete situations when this skill should fire.

## What you need first

Preconditions to verify before running.

## The workflow

Step-by-step what the agent should do. Reference `scripts/` for deterministic ops.

## Reporting back to the user

What to include in the response after the skill runs.

## Safety considerations

Any security or correctness concerns.

## Edge cases

How the skill handles common failure modes.
```

### `evals/evals.json` template

```json
{
  "skill_name": "my-skill",
  "evals": [
    {
      "id": 0,
      "name": "happy-path",
      "prompt": "Realistic user prompt with concrete file paths and specific intent.",
      "expected_output": "What the skill should do — be specific about side effects and outputs.",
      "files": []
    }
  ]
}
```

Test prompts should be **realistic** — what an actual user would type, including casual phrasing, abbreviations, sometimes typos. Not abstract. Not "Process the file."

---

## PR workflow

1. **Open an issue first** for new skills — check that no one's already working on it and confirm the use case fits scope.
2. **Fork + branch** from `main`. Branch name like `skill/<name>` or `fix/<area>`.
3. **Implement + commit** with conventional-commit-ish messages (`feat(share-md): ...`, `fix(...)`, `docs(...)`).
4. **Run evals** locally:
   ```bash
   # snapshot the existing skill
   cp -R skills/<name> skills/<name>-workspace/iteration-N/skill-snapshot-old/
   # ... run your eval cycle (see existing skills for patterns)
   ```
5. **Open PR** with:
   - Link to the issue
   - Eval results (before/after if modifying existing)
   - Screenshot or transcript showing skill in action
6. **Address review** — maintainer will check eval coverage, security, and skill quality.
7. **Merge** + tag if it's a substantive release.

### Commit message format

We loosely follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `perf`, `security`.
Scope is the skill name (e.g., `share-md`) or `repo` for cross-cutting changes.

Example:

```
feat(share-md): add --encrypt flag using AES-256-CBC

- New _encrypt.sh helper wraps openssl
- Auto-generates 32-char passphrase, prints with OUT-OF-BAND warning
- Updates SKILL.md to describe new flag and safety nuance

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Code style

### Shell scripts

- `set -euo pipefail` at the top (use `set -uo pipefail` only when intentional partial-failure tolerance is needed; document why)
- Quote everything: `"$file"`, `"$gist_id"`, etc.
- `shellcheck` clean (we'll add CI for this in iteration-3)
- Helper scripts get a leading underscore: `_with_lock.sh`, `_encrypt.sh`
- Error messages go to stderr with a clear remediation
- Don't punt errors to the agent — handle them in the script with helpful messages

### Markdown

- 80-char soft wrap (not enforced, just sensible)
- Code fences with language tag (`bash`, `json`, etc.)
- Headers in sentence case ("Auto-delete via launchd", not "Auto-Delete Via Launchd")

---

## Testing

Every PR should be testable end-to-end. Prefer real fixtures over mocks for shell scripts (the integration is the value).

### Eval cycle

Use the `skill-creator` skill or follow the pattern in `skills/share-md-workspace/iteration-2/`:

1. Snapshot the old skill version
2. Spawn N subagents (your version vs. snapshot) with realistic prompts
3. Save transcripts + gist IDs (for cleanup)
4. Synthesize benchmark.md comparing results
5. Clean up any side-effect resources (gists, plists, etc.)

### Manual e2e

For shell scripts, an `e2e.sh` test harness is recommended. See `share-md`'s test pattern in past commits for inspiration.

---

## Security

If you discover a security issue:

- **Do not** open a public issue or PR
- Email the maintainer or use GitHub's [private vulnerability reporting](https://github.com/kirollosatef/skills/security/advisories/new)
- Allow reasonable time for a fix before disclosing

For non-critical security improvements (defense in depth, hardening, better error messages), open a regular issue/PR.

---

## Code of conduct

Be kind. Be specific. Disagree with arguments, not people. If you wouldn't say it to a colleague's face, don't write it in an issue.

---

## License

By contributing, you agree your contributions will be licensed under the [MIT License](LICENSE).
