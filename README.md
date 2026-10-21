# Material 3 Frosted

**The Android 17 frosted-glass design system as an agent skill.** Translucent, blurred chrome
over Material 3 Expressive — with the placement rules, fallbacks and accessibility that separate
a real Android 17 look from a glassmorphism demo.

[![skills.sh](https://img.shields.io/badge/skills.sh-material--3--frosted-6E56CF)](https://skills.sh/)

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
| `assets/examples/*.kt` | 5 copy-adapt Compose implementations |
| `assets/templates/*.md` | Audit report and upgrade plan skeletons |
| `scripts/scan_ui.py` | Static UI scanner for existing apps (Phase 0) |

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

## Platform support

| | Support |
|---|---|
| Jetpack Compose | Primary target |
| Views / MD2 | Migration path + platform window blur (no composable glass layer) |
| Flutter | `BackdropFilter` blur only — no refraction/Glass equivalent |
| Web | Not covered; Material Web is in maintenance mode and does not implement Expressive |

Haze 2 requires **API 31+**; Glass refraction requires **API 33+** (AGSL).

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
├── tests/plugin_layout_test.sh
├── install.sh
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `./tests/plugin_layout_test.sh` before opening a PR.

## License

MIT — see [LICENSE](LICENSE).
