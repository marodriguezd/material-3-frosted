# Material 3 Frosted

**The Android 17 frosted-glass design system as an agent skill.** Translucent, blurred chrome
over Material 3 Expressive — with the placement rules, fallbacks and accessibility that separate
a real Android 17 look from a glassmorphism demo.

[![skills.sh](https://img.shields.io/badge/skills.sh-material--3--frosted-6E56CF)](https://www.skills.sh/marodriguezd/material-3-frosted)
[![validate](https://github.com/marodriguezd/material-3-frosted/actions/workflows/validate.yml/badge.svg)](https://github.com/marodriguezd/material-3-frosted/actions/workflows/validate.yml)

---

## Install

```bash
npx skills add marodriguezd/material-3-frosted --skill material-3-frosted
```

Claude Code, via the plugin marketplace:

```
/plugin marketplace add marodriguezd/material-3-frosted
/plugin install material-3-frosted@material-3-frosted
```

**Any other agent, any path.** The skill is one self-contained directory with no install step —
copy `skills/material-3-frosted/` wherever your assistant looks for skills. The bundled
installer auto-detects the common homes:

```bash
./install.sh                      # ~/.agents/skills, ~/.claude/skills, ~/.codex/skills…
./install.sh --target DIR         # exactly where you want it
./install.sh --list               # show candidate targets
SKILLS_DIR=DIR ./install.sh       # same, scriptable
```

Or simply:

```bash
cp -R skills/material-3-frosted ~/.agents/skills/
```

Nothing in the skill assumes where it lives: every reference is resolved relative to the folder
containing `SKILL.md`, and there are no absolute paths anywhere in the tree (a check enforces
this — see `tests/plugin_layout_test.sh`).

---

## What it does

Android 17 (API 37, "Cinnamon Bun") made **depth through translucency** the signature of the
platform UI: the notification shade, Quick Settings, volume panel and power menu all frost their
chrome over live content. Most app attempts at that look fail in one of three ways:

1. **A semi-transparent rectangle** painted with a hardcoded alpha.
2. **`Modifier.blur()`** — which blurs the composable's *own* content, not the backdrop. This is
   the classic "frosted card that is just a blurry card".
3. **Glass everywhere** — cards, list rows, forms — destroying hierarchy and contrast.

This skill encodes the correct version:

- **Glass placement rule** in three tiers: chrome (yes), media overlays (with a reason), content
  (never).
- **Haze 2 Glass & Blur** — the real backdrop-blur APIs, with the source/effect topology that
  avoids self-sampling and empty frames.
- **Platform window blur** (`Window.setBackgroundBlurRadius`, `FLAG_BLUR_BEHIND`) for dialogs that
  must frost other apps.
- **Guaranteed opaque fallbacks** — blur can vanish at any moment (battery saver, low-end GPU,
  the system *Reduce blur effects* toggle). Every glass surface is designed non-blurred first.
- **Accessibility**: `GlassAccessibilitySettings`, contrast over glass, font scale 2.0, reduced
  motion, TalkBack.
- **The Expressive foundation underneath**: tokens, dynamic colour, spring motion, adaptive
  layout — so the glass sits on something current.

## What's inside

| Path | Contents |
|------|----------|
| `skills/material-3-frosted/SKILL.md` | The workflow: recon → audit → plan → build → verify, the glass placement rule, anti-patterns |
| `references/glass-effects.md` | Haze 2 Glass/Blur, window blur, fallbacks, accessibility, performance modes |
| `references/expressive-system.md` | Expressive tokens, motion scheme, shape morphing, components, adaptive layout |
| `references/audit-rubric.md` | 12 weighted dimensions and a per-screen score matrix |
| `references/migration-playbook.md` | MD2→MD3, Views→Compose, SDK bumps, edge-to-edge, common breakages |
| `references/tokens-and-color.md` | Colour roles, dynamic colour, contrast, shape/space scale, glass tinting |
| `references/accessibility-and-motion.md` | Reduce-blur, reduced motion, TalkBack, touch targets, spring choices |
| `references/performance.md` | Blur cost model, budgets, `HazePerformanceMode`, measuring |
| `references/platform-matrix.md` | Feature × platform × version, verified against published artifacts |
| `assets/examples/*.kt` | 5 copy-adapt Compose implementations (compiled — see below) |
| `assets/examples/stable/` | The material3 1.4.0 theme, for teams that stay on stable |
| `assets/templates/*.md` | Audit report and upgrade plan skeletons |
| `scripts/scan_ui.py` | Static UI scanner for existing apps (Phase 0) |
| `verify/` | A Gradle harness that actually compiles the examples against the real artifacts |

## Quick start

```bash
# 1. Scan an existing app
python3 skills/material-3-frosted/scripts/scan_ui.py ~/code/myapp --format markdown

# 2. Follow SKILL.md: audit every screen, plan by dependency, add glass last
```

## Verified, not assumed

The version and API claims in this skill were checked against the published artifacts rather
than written from memory. Two findings worth knowing before you start:

- **In `androidx.compose.material3:material3:1.4.0` (the Compose BOM 2026.09.00 default),
  `MaterialExpressiveTheme`, `MotionScheme.expressive()` and `Shapes.largeIncreased` are
  `internal`.** They are only public from `1.5.0-beta01`. The skill pins the override and
  explains the fallback path.
- **`ButtonGroup`, `SplitButton`, `ToggleButton` and `LoadingIndicator` do not exist before
  `1.5.0-beta01`.** `SegmentedButton`, `Carousel`, `ShortNavigationBar` and `WideNavigationRail`
  do exist in 1.4.0 and are the expressive components you can adopt on stable today.

Haze artifacts are released in lockstep — pin them all to the same version (`2.0.1`).

### The examples are compiled, not just proofread

The skill ships `verify/`, a two-module Gradle project that compiles every example against the
real dependencies:

```bash
cd verify
./gradlew :expressive:compileDebugKotlin   # material3 1.5.0-beta01 + Haze 2.0.1, minSdk 23
./gradlew :stable:compileDebugKotlin       # material3 1.4.0, the stable path
```

Writing it paid for itself immediately — the first real build caught four defects that
proofreading had missed:

| Defect | Why it mattered |
|--------|-----------------|
| `hazeGlassContainer` does not exist in Haze 2.0.1 | It is on Haze's `main` branch only. Every tutorial that mentions it would have produced a compile error. |
| `ModalBottomSheetDefaults.DragHandle` | The handle lives on `BottomSheetDefaults` in current material3. |
| Examples referenced `AppTypography` / `AppShapes` but never defined them | Copy-paste would not compile. They now ship as `FrostedTypography` / `FrostedShapes`. |
| `as? Activity` on `LocalView.current.context` | That context is usually a `ContextWrapper`, so the cast silently returned `null` and window blur never applied. Now unwrapped through the chain. |

**Stated limit:** the harness compiles the examples (`compileDebugKotlin`). It does not
`assembleDebug`, run on a device, or verify pixels. Compiling proves the APIs and signatures are
right; it cannot prove the result looks good — that is design judgment, and the skill's audit
rubric is where that is exercised.

## Platform support

| Target | Support | Verified by |
|---|---|---|
| Jetpack Compose | Full: glass placement, Haze 2 Glass & Blur, expressive layer | `verify/expressive` + `verify/stable` compile |
| Flutter | Full: glass primitive, grouping, the reduce-transparency gap, M3-in-Flutter | `verify/flutter` analyze + widget tests |
| React Native / Expo | Full: native iOS 26 glass, expo-blur Android trap, fallbacks | `verify/react-native` typecheck |
| iOS SwiftUI | Full: `Material`, `.glassEffect`, Reduce Transparency | `swiftc -typecheck` on a macOS runner |
| Views / MD2 | Migration path + platform window blur (no composable glass layer) | docs only |
| Web (CSS) | Not covered; Material Web is in maintenance mode and does not implement Expressive | — |

### One design system, four codebases

Each target has its own reference and its own compiled examples, because the platforms do not
share a primitive:

| | Merging nearby glass | Reduce transparency |
|---|---|---|
| Compose + Haze 2.0.1 | ✗ not released (`hazeGlassContainer` is on `main` only) | ✓ system flag |
| Flutter | ✓ `BackdropGroup` + `BackdropFilter.grouped` | ✗ not exposed — app owns the switch |
| React Native | ✓ `GlassContainer` (iOS 26) | ✓ `AccessibilityInfo` (iOS only) |
| SwiftUI | ✓ `GlassEffectContainer` (iOS 26) | ✓ `@Environment(\.accessibilityReduceTransparency)` |

The placement rule is identical on all four; the primitives are not. That is the whole reason
this skill has per-platform references instead of a translation table.

### API levels — the real numbers

Haze 2.0.1 declares **`minSdk` 23**; it compiles and runs well below 31. What changes is the
quality of the effect:

| API | What you get |
|---|---|
| 33+ | Real blur **and** glass refraction (`RuntimeShader` path) |
| 31–32 | Real blur (RenderEffect); glass draws its static highlight/rim fallback |
| 23–30 | Haze's blur delegate falls back to a **tinted scrim** (`fallbackTint`), not a blur |

The decision is therefore not "what is Haze's minSdk" but "on which API do you accept a scrim
instead of a blur". If your design only reads correctly with a blur, set `minSdk` to 33. If it
reads correctly as a designed scrim, 23 is fine. Details: `references/platform-matrix.md`.

## Structure

```
material-3-frosted/
├── .claude-plugin/
│   └── marketplace.json
├── .github/workflows/validate.yml
├── skills/
│   └── material-3-frosted/
│       ├── .claude-plugin/plugin.json
│       ├── SKILL.md
│       ├── references/
│       ├── assets/{examples,templates}/
│       └── scripts/scan_ui.py
├── verify/
│   ├── settings.gradle.kts
│   ├── gradlew
│   ├── expressive/    # material3 1.5.0-beta01 + Haze 2.0.1
│   └── stable/        # material3 1.4.0
├── tests/plugin_layout_test.sh
├── install.sh
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

`verify/` is a development-only harness: it is **not** copied by `npx skills add` (that command
installs only `skills/material-3-frosted/`), so it adds nothing to the skill's size for users.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `./tests/plugin_layout_test.sh` before opening a PR,
and `cd verify && ./gradlew :expressive:compileDebugKotlin :stable:compileDebugKotlin` after
touching anything in `assets/examples/` — the examples are shipped code, not illustrations.

## License

MIT — see [LICENSE](LICENSE).
