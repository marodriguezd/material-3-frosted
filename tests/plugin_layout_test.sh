#!/usr/bin/env bash
# Layout + portability checks for the material-3-frosted skill repo.
#
# The skill must be UNIVERSAL: it is copied or installed to arbitrary paths by arbitrary
# agents, so nothing may depend on where it lives. These checks enforce that.
set -u

cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
SKILL="skills/material-3-frosted"
failures=0

fail() { printf 'FAIL: %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf 'ok:   %s\n' "$1"; }

expect_file()  { [[ -f "$1" ]] && pass "file $1" || fail "expected file $1"; }
expect_dir()   { [[ -d "$1" ]] && pass "dir  $1" || fail "expected directory $1"; }
expect_absent(){ [[ ! -e "$1" ]] && pass "absent $1" || fail "expected no $1"; }

expect_contains() {
  local path="$1" pattern="$2"
  if [[ ! -f "$path" ]]; then fail "cannot inspect missing $path"; return; fi
  grep -Fq "$pattern" "$path" && pass "$path contains '$pattern'" \
    || fail "$path must contain: $pattern"
}

expect_not_contains() {
  local path="$1" pattern="$2"
  if [[ ! -f "$path" ]]; then fail "cannot inspect missing $path"; return; fi
  if grep -Fq "$pattern" "$path"; then fail "$path must NOT contain: $pattern"; else pass "$path free of '$pattern'"; fi
}

echo "── repo layout ─────────────────────────────────────────────"
expect_file ".claude-plugin/marketplace.json"
expect_contains ".claude-plugin/marketplace.json" '"name": "material-3-frosted"'
expect_contains ".claude-plugin/marketplace.json" "\"path\": \"$SKILL\""
expect_absent ".claude-plugin/plugin.json"

expect_file "$SKILL/.claude-plugin/plugin.json"
expect_contains "$SKILL/.claude-plugin/plugin.json" '"name": "material-3-frosted"'
expect_contains "$SKILL/.claude-plugin/plugin.json" '"version"'

# The skill content must live under skills/<name>/, never at the repo root.
expect_absent "SKILL.md"
expect_absent "references"
expect_absent "assets"
expect_absent "scripts"

expect_file "$SKILL/SKILL.md"
expect_dir  "$SKILL/references"
expect_dir  "$SKILL/assets/examples"
expect_dir  "$SKILL/assets/templates"
expect_file "$SKILL/scripts/scan_ui.py"

expect_file "README.md"
expect_contains "README.md" "npx skills add"
expect_contains "README.md" "$SKILL/SKILL.md"
expect_contains "README.md" "/plugin marketplace add"
expect_file "LICENSE"
expect_file "CONTRIBUTING.md"

echo "── frontmatter ─────────────────────────────────────────────"
head -1 "$SKILL/SKILL.md" | grep -q '^---$' && pass "frontmatter opens" || fail "SKILL.md must start with ---"
grep -qx -- '---' <(sed -n '2,40p' "$SKILL/SKILL.md") && pass "frontmatter closes" || fail "frontmatter never closes"
expect_contains "$SKILL/SKILL.md" "name: material-3-frosted"
expect_contains "$SKILL/SKILL.md" "description:"

echo "── portability: no absolute paths ──────────────────────────"
# Any absolute path to a home dir or this machine's layout is a portability bug.
#
# The scan covers every language the skill now ships (Kotlin, Dart, TypeScript,
# Swift) plus the docs. Vendored and generated trees are excluded: a dependency's
# own fixtures say nothing about whether *the skill* is portable, and
# node_modules alone contains thousands of them.
if grep -rn --include='*.md' --include='*.py' --include='*.kt' --include='*.kts' \
     --include='*.dart' --include='*.ts' --include='*.tsx' --include='*.swift' \
     --include='*.json' --include='*.sh' --include='*.yml' \
     --exclude-dir=node_modules --exclude-dir=build --exclude-dir=.gradle \
     --exclude-dir=.dart_tool --exclude-dir=__pycache__ --exclude-dir=.git \
     --exclude-dir=.agents --exclude-dir=.claude \
     -E '(/home/[a-z]|/Users/[A-Za-z]|C:\\\\Users)' \
     . | grep -v 'tests/plugin_layout_test.sh' | grep -v 'CONTRIBUTING.md'; then
  fail "absolute user paths found (see above) — the skill must work from any path"
else
  pass "no absolute user paths"
fi

# Skill-relative references must be relative, never rooted.
if grep -rn --include='*.md' -E '`/[A-Za-z]' "$SKILL" | grep -v 'https://'; then
  fail "rooted paths in markdown (see above)"
else
  pass "all resource references are relative"
fi

echo "── portability: scanner runs from a foreign path ───────────"
tmp="$(mktemp -d)"
cp -r "$SKILL" "$tmp/copied-skill"
if python3 "$tmp/copied-skill/scripts/scan_ui.py" "$tmp/copied-skill" --format text >/dev/null 2>&1; then
  pass "scanner works from a copied location"
else
  fail "scanner failed when run from a copied location"
fi
python3 -m py_compile "$tmp/copied-skill/scripts/scan_ui.py" 2>/dev/null \
  && pass "scanner compiles" || fail "scanner does not compile"
rm -rf "$tmp"

echo "── internal links ──────────────────────────────────────────"
missing=0
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  if [[ "$ref" == *'*'* ]]; then
    # shellcheck disable=SC2086
    compgen -G "$SKILL/$ref" >/dev/null || { fail "glob matches nothing: $ref"; missing=$((missing+1)); }
  else
    [[ -e "$SKILL/$ref" ]] || { fail "broken reference: $ref"; missing=$((missing+1)); }
  fi
done < <(grep -rhoE '`((references|assets|scripts)/[^`]+)`' "$SKILL/SKILL.md" | tr -d '`' | sort -u)
[[ "$missing" -eq 0 ]] && pass "no broken references in SKILL.md"

echo
if [[ "$failures" -gt 0 ]]; then
  printf '%d check(s) failed.\n' "$failures"
  exit 1
fi
printf 'All layout and portability checks passed.\n'
