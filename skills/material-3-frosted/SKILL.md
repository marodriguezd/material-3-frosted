---
name: material-3-frosted
description: >
  The Android 17 / frosted-glass design system for apps: translucent, blurred glass chrome
  (Haze 2 Glass & Blur, platform window blur) layered over Material 3 Expressive. Covers the
  glass placement rules, glass over scrolling content, blur fallbacks and reduce-blur
  accessibility, expressive tokens, spring motion, shape morphing and adaptive layout. Use when
  asked for "frosted glass", "liquid glass", "glassmorphism", "blurred / translucent UI",
  "the Android 17 look", "Cinnamon Bun style", "make my app look modern", "Material 3
  Expressive", "upgrade / modernize my Android UI", "migrate MD2 to MD3", or to audit an
  Android app's design-system and glass usage. Primary target: Jetpack Compose; also covers
  Views/MD2 migration, Flutter, accessibility and performance budgets.
user-invokable: true
argument-hint: "[audit|upgrade|glass|theme|screen] [path, screen name, or URL]"
---

# Material 3 Frosted — the Android 17 frosted-glass design system

Android 17's most visible UI change is **depth through translucency**: chrome that floats over
the content, blurs what is behind it, and shifts as you scroll. This skill teaches an AI coding
assistant how to build that look *correctly* — because the naive version (a semi-transparent
rectangle, or `Modifier.blur()` on the wrong node) is cheap, common, and wrong.

The look has two layers, and you need both:

| Layer | What it is | Where it comes from | Reference |
|-------|-----------|---------------------|-----------|
| **A — Frosted** | The signature: glass chrome over scrolling content, blurred sheets, translucent overlays, refraction, specular edges | Haze 2 (Glass + Blur), platform window blur | `references/glass-effects.md` |
| **B — Expressive** | The foundation the glass sits on: tokens, colour, typography, shape, spring motion, components, adaptive layout | Material 3 Expressive (Compose Material3 **1.5.0-beta01+**) | `references/expressive-system.md` |

**B is the foundation; A is the accent.** Glass over an app that is still on MD2 tokens —
hardcoded colours, 4dp corners, `tween(300)` everywhere — looks worse than no glass at all. So
the workflow below fixes the foundation first and adds glass last, even though glass is the
thing you came for.

This is also a **migration** skill: it assumes the app already works, and the job is to make it
look like 2026 without breaking it.

### Portability — read once

This skill is a **single self-contained directory**: `SKILL.md`, `references/`, `assets/`,
`scripts/`. It has no install step, no daemon, no dependency on where it lives, and no
assumption about the host project.

**Resolve every path in this skill relative to the directory containing this `SKILL.md`** —
never relative to the project's working directory, and never as an absolute path. Agents place
skills in different homes (`~/.agents/skills/`, `~/.claude/skills/`, a project's
`.agents/skills/`, a vendored folder, a temp dir), and this skill must behave identically in all
of them.

```bash
# where <skill-dir> is the folder holding this SKILL.md
python3 <skill-dir>/scripts/scan_ui.py <project-path> --format markdown
```

If your agent exposes the skill's base directory (most do), use it as `<skill-dir>`. If it does
not, the path is wherever the skill was copied — `find / -name SKILL.md -path '*material-3-frosted*'`
locates it. When in doubt, read the files with an absolute path you resolved once, and pass the
*target project* as the scanner argument.

---

## 1. Non-negotiable rules

These are the constraints that make the result look like a Google app instead of a demo. They
override any "make it look cool" impulse.

1. **Glass is a functional layer, not a content layer.** It belongs around controls and
   navigation, never under text the user must read. See §4.
2. **Every glass surface has an opaque fallback.** Blur can be disabled by the system
   (`WindowManager.isCrossWindowBlurEnabled()`), by battery saver, by the user's
   *Settings → Accessibility → Color & motion → Reduce blur effects* toggle, or by hardware
   limits. Design the non-blur state first; the blur is the enhancement.
3. **Text on glass must keep its contrast.** Glass is tinted with a real surface colour
   (`surfaceContainer*`), never a random alpha of the primary. If you can't show the contrast
   ratio holding in both light and dark, don't put text on glass.
4. **Use semantic tokens only.** `MaterialTheme.colorScheme.*`, `MaterialTheme.shapes.*`,
   `MaterialTheme.typography.*`. No `Color(0x…)` for surfaces, no magic `.dp` values where a
   shape/space token exists.
5. **Motion respects the system.** Spring physics are the default, but when the system animation
   scale is 0 the animation must be instant, not fast. Provide the reduced-motion path.
6. **Labels stay.** Do not strip text labels from nav items, tabs, or icon buttons "to look
   cleaner". Keep `contentDescription` on every icon-only control.
7. **Touch targets stay ≥ 48dp.** Glass, morphing shapes, and springs must not shrink hit areas.
8. **Max 1–2 hero moments per flow.** A screen where everything is expressive is expressive
   nowhere.
9. **No fake Material.** A frosted card is not an M3 `Card`. If you replace an M3 component with
   a glass rectangle, you must reproduce the component's semantics, states, and accessibility.
10. **Don't break what works.** Refactor structure when the upgrade requires it, but keep
    behaviour, tests, and navigation intact. Land the change in reviewable increments.

---

## 2. Intake

Ask only what you cannot infer, and **infer the rest from the code** (Phase 0). Never block on
questions you can answer by reading the repo.

| Question | Default if unknown |
|----------|--------------------|
| Target device class (phone / foldable / tablet / Wear / TV)? | Phone + foldable, verify both |
| Min window size class to support? | Compact (phone) |
| Brand identity to preserve, or full dynamic color? | Dynamic color on API 31+, brand fallback |
| Is the app Views, Compose, or mixed? | Infer from the code |
| Is there a design system / custom theme already? | Infer |
| How aggressive may the visual change be? | Structure-preserving, visual refresh allowed |
| Any hard brand constraints (e.g. "the bottom bar must stay blue")? | Ask — this is the one that costs rework |

---

## 3. The workflow

Four phases. **Do not skip Phase 1.** An upgrade without an inventory silently leaves 30% of
the app on the old design, which is exactly the failure this skill exists to prevent.

```
Phase 0  RECON   → detect stack, versions, and the true size of the job
Phase 1  AUDIT   → inventory EVERY screen; score 12 dimensions; produce a report
Phase 2  PLAN    → ordered workstreams, dependencies, risk, acceptance criteria
Phase 3  BUILD   → implement in dependency order (theme → components → screens → glass)
Phase 4  VERIFY  → build, test, screenshot, measure; close the report
```

### Phase 0 — Recon (read-only)

Run the bundled scanner, then read the files it points at:

```bash
python3 <skill-dir>/scripts/scan_ui.py <path-to-android-project> --format markdown
```

It reports: SDK levels, Compose vs Views ratio, MD2 usage, hardcoded colours/dimensions,
missing dynamic colour, `enableEdgeToEdge` absence, missing `MaterialTheme` usage, blur
misuse, hardcoded strings, missing `contentDescription`, and whether Haze is already a
dependency. It is a starting point, **not** the audit — it cannot see hierarchy, hierarchy
quality, or visual balance. Cross-check every hit by opening the file.

Then determine, by hand:

- **Every screen** the user can reach (including dialogs, bottom sheets, empty states, error
  states, onboarding, settings, and system surfaces like the app's own notification shade).
- **Every custom component** in a shared module. These pay off the most — fix a component once
  and 40 screens inherit it.
- **The theme entry point** (`Theme.kt`, `themes.xml`, `styles.xml`) and the actual source of
  truth for colour, type, shape.
- **Where content scrolls under chrome** (this decides where glass is even possible).

### Phase 1 — Audit

Score every screen on the 12 dimensions of `references/audit-rubric.md`:

`Color · Typography · Shape · Motion · Depth/elevation · Components · Layout/adaptive ·
Navigation · Glass/translucency · Accessibility · Performance · Platform readiness`

Produce **one report**, not twelve. Per screen: a score row, the concrete defects with
`file:line`, and the fix. Use `assets/templates/audit-report.md`.

The output of this phase is a **screen matrix** — the mechanism that makes "100% of the UI"
real:

| Screen | Color | Type | Shape | Motion | Depth | Comp. | Layout | Nav | Glass | A11y | Perf | Platform | Action |
|--------|-------|------|-------|--------|-------|-------|--------|-----|-------|------|------|----------|--------|
| Home | 6 | 8 | 4 | 2 | 5 | 7 | 5 | 8 | 3 | 6 | 7 | 4 | Upgrade |
| Detail | … | | | | | | | | | | | | |

A screen is **done** only when every dimension is ≥ 8. That is the bar; not "the main screen
looks nice".

### Phase 2 — Plan

Order work by **dependency**, not by screen. Typical order:

1. **Foundation** — SDK levels, Compose BOM, dynamic colour, `MaterialExpressiveTheme`,
   typography, shapes, motion scheme, `enableEdgeToEdge()`.
2. **Shared components** — buttons, cards, text fields, lists, nav bar, top bar, FAB, sheets.
   This is where most of the visual gain is.
3. **Layout & adaptive** — window size classes, canonical layouts, foldables, insets.
4. **Screen-by-screen** — now the screens are cheap.
5. **Glass layer** — last, once the underlying surfaces are correct. Glass over a broken
   layout just makes the breakage shiny.
6. **Motion polish & hero moments** — the expressive flourish, budgeted to 1–2 per flow.

For each workstream: files touched, risk, and an acceptance criterion you can check. Use
`assets/templates/upgrade-plan.md`.

### Phase 3 — Build

Work in reviewable increments, each one shippable. Reference implementations live in
`assets/examples/`:

| File | What it shows |
|------|---------------|
| `assets/examples/FrostedTheme.kt` | `MaterialExpressiveTheme` + shared Glass/Blur styles + accessibility wiring |
| `assets/examples/FrostedScaffold.kt` | Edge-to-edge scaffold with a glass top bar and glass bottom bar over scrolling content |
| `assets/examples/GlassChrome.kt` | Glass app bar, navigation bar, FAB, and a merged glass control group |
| `assets/examples/GlassSheet.kt` | Modal bottom sheet with a glass header, scrim, and an opaque fallback |
| `assets/examples/WindowBlur.kt` | Platform window blur (background blur + blur behind) with the enabled/disabled listener |

Do **not** paste a whole app from these files. Adapt the pattern to the target's own design
system. If the app has a `ui/theme` package, the upgrade belongs there, not in a parallel
package that will drift.

### Phase 4 — Verify

A "done" upgrade passes **all** of these:

- [ ] `./gradlew assemble<Variant>` succeeds; `./gradlew lint` is clean for the touched modules.
- [ ] Existing unit and UI tests pass (fix or update, never delete, to silence a failure).
- [ ] Screenshot tests (if present) updated for intentional visual change.
- [ ] Every screen in the matrix is ≥ 8 on all 12 dimensions.
- [ ] Light **and** dark theme reviewed on every changed screen.
- [ ] Dynamic colour on and off reviewed (the app must not break with wallpaper-derived hues).
- [ ] Compact, Medium, and Expanded width reviewed; foldable hinge respected.
- [ ] Font scale 1.0 **and** 2.0 reviewed (glass chrome must not clip at large font sizes).
- [ ] Animation scale 0 (reduced motion) reviewed — transitions are instant, not broken.
- [ ] "Reduce blur effects" ON reviewed — content is still fully legible and opaque enough.
- [ ] TalkBack walkthrough on the changed screens.
- [ ] Frame timing measured on a mid-range device with the glass layer enabled (see
      `references/performance.md`).
- [ ] Contrast verified: 4.5:1 body text, 3:1 large text and non-text, **including text on
      glass**.

---

## 4. The Glass Placement Rule

The single most important judgment in this skill — the one that separates "Android 17 native"
from "glassmorphism demo". Glass is a *material for chrome*; the content layer stays opaque M3
surfaces. Apple's guidance for its equivalent material (Liquid Glass) reserves it for controls
and navigation, not content, and the same holds on Android: Android 17's own System UI
(notification shade, Quick Settings, volume, power menu) frosts chrome and keeps content
opaque.

### Tier 1 — Glass chrome (default on)

| Surface | Why | Notes |
|---------|-----|-------|
| Top app bar, scrolled state | Establishes the depth story; content scrolls under it | Must be transparent when un-scrolled, or it looks like a mistake |
| Bottom navigation bar | The other big chrome plane | Use `containerColor = Color.Transparent` + glass on the modifier |
| Navigation rail / drawer (medium+) | Same | |
| FAB and FAB menu | Floats over content; glass reads as "floating" | Keep the FAB's own M3 colour semantics; the glass is the container |
| Segmented control / button group | Apple: "glass *button* style", not a generic backdrop under a normal button | Prefer a merged glass group (`hazeGlassContainer`) |
| Modal bottom sheet header & scrim | Depth between the sheet and the page | The sheet body itself stays opaque |
| Date/time picker header | | |
| Search bar (expanded state) | | |

### Tier 2 — Glass, selectively (only with a reason)

| Surface | When it is justified |
|---------|---------------------|
| Media player controls over a video/photo | The content behind is media, not text |
| Hero card over imagery | The card is a control, not a paragraph |
| Floating overlays on a map or canvas | |
| A "now playing" mini-player | |

### Tier 3 — Never glass

| Surface | Why |
|---------|-----|
| Body text containers, list rows, article cards | Contrast and readability; also the classic "fake Material" failure |
| Text fields and forms | Focus + legibility; the IME overlays them |
| Snackbar and bottom-app-bar notification text | `inverseSurface` is the correct token |
| Full-screen scrims/dialogs over content | Use `scrim`/`surface` tokens |
| Anything a user reads for more than ~2 seconds | Glass reduces effective contrast |
| Buttons that carry a primary action | Glass on a primary CTA reduces its prominence; use the M3 filled button |

### Rules of application

- **One glass plane per screen region.** A screen with a glass top bar, glass bottom bar, glass
  FAB *and* glass cards is noise.
- **Text on glass gets a tint, not a hope.** Use `containerColor = surfaceContainerLow` (or
  `surfaceContainer`) with a tint, and verify contrast in both themes.
- **Merge, don't stack.** `Modifier.hazeGlassContainer(spacing = …)` makes nearby glass surfaces
  read as one object (a toolbar, a segmented control) instead of a pile of separate panes.
- **Blur radius is not a brand value.** Start with `HazeMaterials.thin()` / `GlassStyle.regular`
  and only tune after measuring. Large radii on large surfaces are the #1 cause of jank.
- **Never blur the content the user is reading to do the task.** If in doubt, it is Tier 3.

---

## 5. Decision tree

```
What is the app built with?
├─ Views + MD2 (com.google.android.material)   → migration-playbook.md § Views→Compose / MD2→MD3
│                                                 (do NOT add glass until MD3 tokens are in place)
├─ Views + MD3 (Material Components 1.14)       → keep Views; adopt MD3 theming + expressive components
│                                                 where available; glass via platform window blur
├─ Compose, no MaterialTheme                    → foundation first: theme, tokens, then components
├─ Compose + MD3, non-expressive                → Phase A only: expressify (motion, shape, type)
│                                                 bump material3 to 1.5.0-beta01 first, or you
│                                                 cannot call MaterialExpressiveTheme at all
├─ Compose + Expressive, no glass               → add the glass layer, Tier 1 only
└─ Compose + Expressive + glass                 → audit for overuse, perf, and a11y
```

```
Is the ask "make it modern" with no specifics?
└─ Default: Foundational Expressive intensity + Tier-1 glass + dynamic colour
   + edge-to-edge + adaptive navigation. Ship that. Then iterate.
```

---

## 6. Stack pins

Use the versions below unless the project already pins newer ones. **Keep every Haze artifact on
the same version** — they are released in lockstep.

```kotlin
// app/build.gradle.kts
dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)

    // The BOM pins material3 1.4.0, where the Expressive APIs are INTERNAL.
    // Override the version explicitly to get them — see "Version reality" below.
    implementation("androidx.compose.material3:material3:1.5.0-beta01")
    implementation("androidx.compose.material3:material3-adaptive-navigation-suite:1.5.0-beta01")
    implementation("androidx.compose.material3:material3-window-size-class")   // via BOM, 1.4.0 is fine
    implementation("androidx.activity:activity-compose:1.13.0")          // enableEdgeToEdge()
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")

    // Frosted layer — pick the modules you actually use, all on ONE version
    implementation("dev.chrisbanes.haze:haze:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur-materials:2.0.1")        // HazeMaterials presets
    implementation("dev.chrisbanes.haze:haze-glass:2.0.1")                // refraction Glass
    implementation("dev.chrisbanes.haze:haze-glass-material3:2.0.1")      // Glass + M3 colours
}
```

```kotlin
// compileSdk 37 (Android 17), targetSdk 37, minSdk: raise only if you can justify it
android {
    compileSdk = 37
    defaultConfig { targetSdk = 37 }
}
```

### Version reality — read this before pinning

Verified against the published artifacts (1.4.0 stable and 1.5.0-beta01), not from memory:

| API | 1.4.0 (stable) | 1.5.0-beta01 |
|-----|----------------|--------------|
| `MaterialExpressiveTheme` | **`internal`** — not callable | `public` |
| `MotionScheme.expressive()` / `.standard()` | **`internal`** | `public` |
| `Shapes.largeIncreased` / `extraLargeIncreased` / `extraExtraLarge` | **`internal`** | `public` |
| `ButtonGroup`, `SplitButton`, `ToggleButton`, `LoadingIndicator` | absent | `public` |
| `FloatingToolbar`, `FloatingActionButtonMenu`, `WavyProgressIndicator`, `ScrollField` | absent | `public` |
| `ShortNavigationBar`, `WideNavigationRail`, `SegmentedButton`, `Carousel`, `SearchBar` | `public` | `public` |

**Consequence:** you cannot "just use Material 3 Expressive" on the BOM default. Either

1. override `material3` to `1.5.0-beta01` (what this skill assumes), or
2. stay on `1.4.0` and get the expressive *components* that already exist there
   (`SegmentedButton`, `Carousel`, `ShortNavigationBar`, `WideNavigationRail`) **without**
   `MaterialExpressiveTheme` and **without** `MotionScheme.expressive()`.

Do not write `MaterialExpressiveTheme(...)` and then leave the BOM at 1.4.0 — it will not
compile. Check the resolved version with `./gradlew :app:dependencies` before believing any
version claim, including the ones in this file.

Version notes and what each release gives you: `references/platform-matrix.md`.

---

## 7. The 60-second M3 Expressive layer

The highest-value, lowest-risk changes. If you only do these, the app already looks a decade
newer.

| Lever | Change |
|-------|--------|
| Theme | `MaterialExpressiveTheme(colorScheme = …, motionScheme = MotionScheme.expressive(), …)` (needs 1.5.0-beta01) |
| Colour | Dynamic colour on API 31+; `surfaceContainer*` roles instead of `surfaceVariant` |
| Type | Use the 15 roles + emphasized variants; `titleLarge` 22sp/28sp SemiBold |
| Shape | Buttons/chips `full`; cards `medium`; sheets `extraLarge`; expressive `largeIncreased` (20dp) / `extraLargeIncreased` (32dp) for hero moments (needs 1.5.0-beta01) |
| Motion | Springs via `MaterialTheme.motionScheme.defaultSpatialSpec()`; no more `tween(300)` for component state |
| Components | On 1.5.0-beta01: `ButtonGroup`, `SplitButton`, `LoadingIndicator`, `ToggleButton`, `WavyProgressIndicator`. On 1.4.0: `SegmentedButton`, `Carousel`, `ShortNavigationBar`, `WideNavigationRail`, `SearchBar` |
| Layout | `NavigationSuiteScaffold` (bar → rail → drawer by width), `currentWindowAdaptiveInfo()`, `ListDetailPaneScaffold` |
| Depth | Tonal elevation by default; shadows only over busy backgrounds |

Details: `references/expressive-system.md`.

---

## 8. Anti-patterns

| Anti-pattern | Why it fails | Do instead |
|--------------|--------------|------------|
| Glass everywhere | Kills hierarchy, destroys contrast, melts the design | Tier 1 chrome only (§4) |
| `Modifier.blur()` used for a backdrop | It blurs the composable's **own** content, not what's behind it | `HazeInput.Backdrop` / `HazeInput.Sources` |
| `hazeSource` on the whole screen *including* the bar | The bar samples itself → recursion/empty frame | Source = scrolling content only; bars are siblings |
| A new `Glass` colour in `Color.kt` | Off-token; breaks dynamic colour and dark mode | `HazeBlurStyle.Material3()` / `GlassStyle.material3()` |
| `tween()` animations everywhere | Reads as MD2; fights the platform | `MaterialTheme.motionScheme` springs |
| Removing nav labels to "de-clutter" | Undiscoverable navigation | Keep labels; use `NavigationRail` on wide screens instead |
| Icon-only FAB with no label, no tooltip | Undiscoverable | `ExtendedFloatingActionButton` or a tooltip |
| Hardcoded `#RRGGBB` in a layout | Breaks dark mode + dynamic colour | Theme attributes |
| `Modifier.clickable` on a 32dp box | Fails touch target | ≥ 48dp, or `LocalMinimumInteractiveComponentSize` |
| Blur with no opaque fallback | Unreadable when the system disables blur | Always design the fallback first |
| Upgrading only the home screen | 70% of the app stays old | Phase 1 inventory + screen matrix |
| Copying a whole app shell from this skill | Foreign design language | Adapt the pattern to the app's own tokens |

---

## 9. Reference index

Load on demand — the tiers are ordered by how often you'll need them.

**Tier 1 — always**
| File | Contents |
|------|----------|
| `references/audit-rubric.md` | The 12 dimensions, scoring, and per-dimension "what to look for" |
| `references/glass-effects.md` | Haze 2 Glass & Blur, window blur, fallbacks, accessibility, anti-patterns |
| `references/expressive-system.md` | Expressive tokens, motion, shape morphing, components, adaptive layout |

**Tier 2 — during the build**
| File | Contents |
|------|----------|
| `references/migration-playbook.md` | MD2→MD3, Views→Compose, dependency + SDK upgrades, edge-to-edge, per-component mapping |
| `references/tokens-and-color.md` | Colour roles, dynamic colour, contrast, shape/space tokens, glass tinting strategy |
| `references/accessibility-and-motion.md` | Reduced motion, reduce-blur, TalkBack, touch targets, font scaling, spring choices |

**Tier 3 — verification & non-Android**
| File | Contents |
|------|----------|
| `references/performance.md` | Blur cost model, `HazePerformanceMode`, measuring, baseline profiles |
| `references/platform-matrix.md` | Feature × platform support, versions, what's Compose-only |

**Assets**
| Path | Contents |
|------|----------|
| `assets/examples/*.kt` | Copy-adapt reference implementations |
| `assets/templates/audit-report.md` | Report skeleton |
| `assets/templates/upgrade-plan.md` | Plan skeleton |
| `scripts/scan_ui.py` | Static UI scanner (Phase 0) |

---

## 10. Relationship to other skills

- `material-3` (hamen) — the M3 token/component catalogue and the MD3 compliance audit. This
  skill builds **on** it: use it for exhaustive component/token lookups, use this one for the
  migration workflow and the glass layer.
- `material-3-expressive` (albermonte) — component-token selection and expressive intensity
  levels. This skill supplies the "how do I migrate an existing app" half and the frosted-glass
  half, which that skill does not cover.
- `frontend-design` — creative direction. **M3 rules win** for component structure and tokens.
  Roboto/Roboto Flex *is* the correct default typeface on Android; ignore any "avoid Roboto"
  guidance for Android targets.
