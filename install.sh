#!/usr/bin/env bash
# install.sh - install one or more skills from kirollosatef/skills
# Usage:
#   curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- <skill-name> [skill-name...]
#   curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- --all
#   curl -sL https://raw.githubusercontent.com/kirollosatef/skills/main/install.sh | bash -s -- --list
#
# Skills install to ~/.claude/skills/<name>/ as a clone of this repo's skills/<name>/.

set -euo pipefail

REPO="kirollosatef/skills"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
TARBALL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
SKILLS_DIR="${HOME}/.claude/skills"

err()  { echo "✗ $*" >&2; exit 1; }
ok()   { echo "✓ $*"; }
info() { echo "→ $*"; }

[[ "${1:-}" ]] || err "no skill specified. use --list to see available, --all to install everything, or pass skill names."

mkdir -p "$SKILLS_DIR"

# fetch + extract once into a temp dir
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

info "fetching repo tarball..."
curl -fsSL "$TARBALL" | tar -xz -C "$TMP" --strip-components=1

available_skills=()
while IFS= read -r dir; do
  name=$(basename "$dir")
  available_skills+=("$name")
done < <(find "$TMP/skills" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$1" == "--list" ]]; then
  echo "available skills:"
  for s in "${available_skills[@]}"; do
    echo "  - $s"
  done
  exit 0
fi

# resolve which skills to install
to_install=()
if [[ "$1" == "--all" ]]; then
  to_install=("${available_skills[@]}")
else
  for arg in "$@"; do
    if [[ ! " ${available_skills[*]} " =~ " ${arg} " ]]; then
      err "unknown skill: $arg. run with --list to see available."
    fi
    to_install+=("$arg")
  done
fi

# install each
for skill in "${to_install[@]}"; do
  src="$TMP/skills/$skill"
  dst="$SKILLS_DIR/$skill"

  if [[ -d "$dst" ]]; then
    info "$skill already installed at $dst — overwriting"
    rm -rf "$dst"
  fi

  cp -R "$src" "$dst"
  find "$dst" -type f -name '*.sh' -exec chmod +x {} \;
  ok "installed $skill -> $dst"
done

echo ""
ok "done. ${#to_install[@]} skill(s) installed."
echo ""
echo "restart Claude Code (or new session) to pick up the new skill(s)."
