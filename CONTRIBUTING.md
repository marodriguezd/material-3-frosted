# Contributing

Thanks for improving the skill. Two rules matter more than anything else here.

## 1. Facts must be verified against artifacts, not memory

This skill makes version and API claims that other people will build on. Every claim about an
API's existence, visibility or signature must be checked against the published artifact before
it lands:

```bash
# Compose Material3 — the authoritative answer on what exists and what is public
curl -s -o m3.aar \
  "https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.5.0-beta01/material3-android-1.5.0-beta01.aar"
unzip -o m3.aar classes.jar && unzip -o classes.jar -d cls
javap -classpath cls androidx.compose.material3.Shapes     # visibility of each property

# Sources give you the exact declaration
curl -sL -o s.jar \
  "https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.5.0-beta01/material3-android-1.5.0-beta01-sources.jar"
unzip -o s.jar -d src && grep -rn "fun MaterialExpressiveTheme" src

# Haze
git clone --depth 1 https://github.com/chrisbanes/haze && grep -rn "public fun Modifier.haze" haze
```

If you cannot verify a claim, do not state it. Write what you observed, and say what you could
not check.

## 2. Examples must parse

The Kotlin in `assets/examples/` is copy-adapt code; a syntax error wastes the reader's time.

```bash
kotlinc assets/examples/FrostedTheme.kt -d /tmp/out
# Unresolved references are expected (no Android SDK / Compose on a bare JDK).
# Any error that is NOT an unresolved-reference consequence is a bug.
```

## Before opening a PR

```bash
./tests/plugin_layout_test.sh          # repo layout + manifests
python3 -m py_compile skills/material-3-frosted/scripts/scan_ui.py
python3 skills/material-3-frosted/scripts/scan_ui.py . --format text   # scanner still runs
```

All three must pass. The layout test also enforces that `SKILL.md`, `references/` and `assets/`
live under `skills/material-3-frosted/` and never at the repo root.

## Style

- **English** for all skill content (the skills.sh ecosystem is English; user-facing replies can
  be in any language).
- **Prose, not bullet soup.** Tables and checklists are for lookup; the reasoning goes in
  sentences.
- **Say why.** "Don't do X because Y breaks" beats "Never do X".
- **No invented APIs.** If a symbol is `internal`, absent, or renamed, say so and give the
  version.
- Keep `SKILL.md` under ~450 lines. Depth belongs in `references/`, loaded on demand.

## Adding a reference file

1. Create `skills/material-3-frosted/references/<topic>.md`.
2. Add it to the reference index in `SKILL.md` §9 with one line on what it covers.
3. Reference it from at least one other file, or the layout test will not be the only thing
   noticing an orphan.

## Reporting a wrong claim

Open an issue with the artifact version, the command you ran, and the output. Version drift is
the main maintenance burden of this skill; concrete evidence is worth more than a correction.
