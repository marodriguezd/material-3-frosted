#!/usr/bin/env bash
# Stage the skill's Flutter examples into this package.
#
# Same principle as the Kotlin harness in ../: there is exactly ONE copy of each
# example (the one the skill ships), and the verifier copies it in. A second
# hand-maintained copy would drift, and the drift would be invisible until a
# user copied an example that no longer matches the docs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$here/../../skills/material-3-frosted/assets/examples/flutter"
dst="$here/lib/examples"

if [ ! -d "$src" ]; then
  echo "FAIL: examples directory not found: $src" >&2
  exit 1
fi

rm -rf "$dst"
mkdir -p "$dst"
cp "$src"/*.dart "$dst"/

# Guard against the failure mode that bit the Kotlin harness: a path that
# resolves to nothing makes the analyzer report "no issues" while checking
# nothing at all.
count=$(find "$dst" -name '*.dart' | wc -l)
if [ "$count" -eq 0 ]; then
  echo "FAIL: staged 0 example files — the verifier would analyse nothing" >&2
  exit 1
fi

echo "staged $count Dart example(s) into $dst"
