#!/usr/bin/env bash
# Universal installer for the material-3-frosted skill.
#
# The skill is a self-contained directory: SKILL.md + references/ + assets/ + scripts/.
# It has no dependency on where it lives, so "installing" is copying that one directory
# into whatever place your agent looks for skills.
#
# Usage:
#   ./install.sh                     # install into every default skills dir
#   ./install.sh --target DIR        # install into an exact directory
#   ./install.sh --sync              # mirror the npx-managed copy into Antigravity
#   ./install.sh --list              # show what would be targeted
#   SKILLS_DIR=... ./install.sh      # same as --target, scriptable
#
# Works on Linux, macOS and Git Bash on Windows. No sudo, no network.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SELF_DIR/skills/material-3-frosted"
SKILL_NAME="material-3-frosted"
# What gets copied. Defaults to the repo; --sync switches it to the copy that
# `npx skills` manages in ~/.agents/skills.
SKILL_FROM="$SKILL_SRC"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

[[ -f "$SKILL_SRC/SKILL.md" ]] || die "cannot find $SKILL_SRC/SKILL.md — run this from the repo root"

# Directories the default install writes. Each is a skills *parent*; the skill is
# copied to <dir>/material-3-frosted.
#
#   FreeBuff / Codex / OpenCode   $HOME/.agents/skills  (agent-compatible global)
#   Antigravity App + IDE         $HOME/.gemini/config/skills
#   Antigravity CLI               $HOME/.gemini/antigravity-cli/skills
#   Claude Code                   $HOME/.claude/skills
#
# Manual targets (not written by default, because a second copy is ambiguous or
# the agent already reads ~/.agents/skills): ~/.config/opencode/skills (OpenCode
# native), ~/.codex/skills (legacy Codex), ./.agents/skills (project scope).
default_dirs() {
  printf '%s\n' "$HOME/.agents/skills"
  printf '%s\n' "$HOME/.gemini/config/skills"
  printf '%s\n' "$HOME/.gemini/antigravity-cli/skills"
  printf '%s\n' "$HOME/.claude/skills"
}

manual_dirs() {
  printf '%s\n' "$HOME/.config/opencode/skills"
  printf '%s\n' "$HOME/.codex/skills"
  printf '%s\n' "$SELF_DIR/.agents/skills"
}

# Refuse to install over the source tree. `--target skills` from the repo root used to
# resolve to the source itself, delete it, and then fail on the copy.
assert_not_source() {
  local target="$1" target_real src_real out_real
  [[ -d "$target" ]] || mkdir -p "$target"
  target_real="$(cd "$target" && pwd -P)"
  src_real="$(cd "$SKILL_FROM" && pwd -P)"
  out_real="$target_real/$SKILL_NAME"
  if [[ "$target_real" == "$src_real" || "$target_real" == "$src_real"/* ||
        "$out_real" == "$src_real" || "$out_real" == "$src_real"/* ]]; then
    die "target resolves to the skill source ($src_real); refusing to overwrite it"
  fi
}

install_into() {
  local dest="$1"
  assert_not_source "$dest"
  local out="$dest/$SKILL_NAME"
  local tmp="$dest/.$SKILL_NAME.tmp.$$"

  # Copy first, swap afterwards: a failed copy must leave the current install intact.
  rm -rf "$tmp"
  mkdir -p "$tmp"
  cp -R "$SKILL_FROM/." "$tmp/"

  # Do not ship local caches or OS noise that happened to be in the source tree.
  find "$tmp" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
  find "$tmp" -name '.DS_Store' -delete 2>/dev/null || true

  chmod +x "$tmp/scripts/scan_ui.py" 2>/dev/null || true

  rm -rf "$out"
  mv "$tmp" "$out"
  printf 'installed → %s\n' "$out"
}

case "${1:-}" in
  --list)
    echo "repo skill: $SKILL_SRC"
    echo "default targets:"
    default_dirs | while read -r d; do
      if [[ -d "$d" ]]; then
        printf '  %s (exists)\n' "$d"
      else
        printf '  %s\n' "$d"
      fi
    done
    echo "manual targets (use --target):"
    manual_dirs | while read -r d; do
      if [[ -d "$d" ]]; then
        printf '  %s (exists)\n' "$d"
      else
        printf '  %s\n' "$d"
      fi
    done
    exit 0
    ;;
  --target)
    [[ -n "${2:-}" ]] || die "--target needs a directory"
    install_into "$2"
    ;;
  --sync)
    # `npx skills` writes one canonical copy to ~/.agents/skills and does not fill
    # Antigravity's own global directories, which it does not read. Mirror the
    # canonical copy there so `npx skills update -g && ./install.sh --sync` keeps
    # every agent on the same version.
    SKILL_FROM="$HOME/.agents/skills/$SKILL_NAME"
    [[ -f "$SKILL_FROM/SKILL.md" ]] \
      || die "no canonical install at $SKILL_FROM — run ./install.sh or npx skills add first"
    install_into "$HOME/.gemini/config/skills"
    install_into "$HOME/.gemini/antigravity-cli/skills"
    if [[ -d "$(dirname "$HOME/.claude/skills")" ]]; then
      install_into "$HOME/.claude/skills"
    fi
    printf '\nSynced from %s\n' "$SKILL_FROM"
    ;;
  -h|--help)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
  "")
    if [[ -n "${SKILLS_DIR:-}" ]]; then
      install_into "$SKILLS_DIR"
      exit 0
    fi
    # ~/.agents/skills covers FreeBuff, Codex and OpenCode, so installing the native
    # OpenCode directory as well would give OpenCode two skills with the same name.
    # Antigravity is the exception: it does not read ~/.agents/skills globally, so the
    # two Gemini directories are required.
    install_into "$HOME/.agents/skills"
    for d in "$HOME/.gemini/config/skills" \
             "$HOME/.gemini/antigravity-cli/skills" \
             "$HOME/.claude/skills"; do
      if [[ -d "$(dirname "$d")" ]]; then install_into "$d"; fi
    done
    printf '\nDone. The skill is self-contained — you can also just copy\n  %s\nanywhere your agent looks for skills.\n' "$SKILL_SRC"
    ;;
  *)
    die "unknown argument: $1 (try --help)"
    ;;
esac
