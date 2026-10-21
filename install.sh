#!/usr/bin/env bash
# Universal installer for the material-3-frosted skill.
#
# The skill is a self-contained directory: SKILL.md + references/ + assets/ + scripts/.
# It has no dependency on where it lives, so "installing" is copying that one directory
# into whatever place your agent looks for skills.
#
# Usage:
#   ./install.sh                     # auto-detect every known skills dir and install
#   ./install.sh --target DIR        # install into an exact directory
#   ./install.sh --list              # show what would be targeted
#   SKILLS_DIR=... ./install.sh      # same as --target, scriptable
#
# Works on Linux, macOS and Git Bash on Windows. No sudo, no network.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SELF_DIR/skills/material-3-frosted"
SKILL_NAME="material-3-frosted"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

[[ -f "$SKILL_SRC/SKILL.md" ]] || die "cannot find $SKILL_SRC/SKILL.md — run this from the repo root"

# Directories that skill-aware agents read, in order of preference.
candidate_dirs() {
  # Generic / agentskills.io convention (used by `npx skills add`)
  printf '%s\n' "$HOME/.agents/skills"
  # Claude Code personal + project scope
  printf '%s\n' "$HOME/.claude/skills"
  # Project-local, if we are inside a project
  printf '%s\n' "$SELF_DIR/.agents/skills"
  # Other common homes; only used if the parent exists
  printf '%s\n' "$HOME/.codex/skills"
  printf '%s\n' "$HOME/.config/agents/skills"
}

install_into() {
  local dest="$1"
  mkdir -p "$dest"
  local out="$dest/$SKILL_NAME"
  rm -rf "$out"
  mkdir -p "$out"
  cp -R "$SKILL_SRC/." "$out/"
  chmod +x "$out/scripts/scan_ui.py" 2>/dev/null || true
  printf 'installed → %s\n' "$out"
}

case "${1:-}" in
  --list)
    echo "repo skill: $SKILL_SRC"
    echo "candidate targets:"
    candidate_dirs | while read -r d; do printf '  %s\n' "$d"; done
    exit 0
    ;;
  --target)
    [[ -n "${2:-}" ]] || die "--target needs a directory"
    install_into "$2"
    ;;
  -h|--help)
    sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
  "")
    if [[ -n "${SKILLS_DIR:-}" ]]; then
      install_into "$SKILLS_DIR"
      exit 0
    fi
    # Install into ~/.agents/skills always; add the others only when their parent exists,
    # so we do not litter a machine with directories for agents it does not run.
    install_into "$HOME/.agents/skills"
    for d in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.config/agents/skills"; do
      if [[ -d "$(dirname "$d")" ]]; then install_into "$d"; fi
    done
    printf '\nDone. The skill is self-contained — you can also just copy\n  %s\nanywhere your agent looks for skills.\n' "$SKILL_SRC"
    ;;
  *)
    die "unknown argument: $1 (try --help)"
    ;;
esac
