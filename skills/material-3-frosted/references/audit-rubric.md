# Audit rubric — 12 dimensions

Used in Phase 1. Score **every screen** on every dimension. The goal is not a number, it is a
complete, prioritised list of defects with file:line references.

**Scoring**

| Score | Meaning |
|-------|---------|
| 9–10 | Compliant. No action. |
| 7–8 | Minor deviations. Note and move on. |
| 4–6 | Real gaps. Fix in this upgrade. |
| 1–3 | Broken or legacy. Must fix. |
| 0 | Not applicable — score it N/A, do not average it in. |

**Overall score** = weighted mean of applicable dimensions. Weights matter: a screen can look
beautiful and still be unusable.

| Dimension | Weight | Why |
|-----------|--------|-----|
| Accessibility | 1.5 | Non-negotiable; also a legal requirement in many markets |
| Components | 1.5 | The visible surface of the app |
| Navigation | 1.25 | Users' ability to get anywhere |
| Layout/adaptive | 1.25 | Breaks on 60% of today's devices |
| Color tokens | 1.0 | Dark mode + dynamic colour correctness |
| Typography | 1.0 | Legibility and hierarchy |
| Shape | 0.75 | Recognisability |
| Motion | 0.75 | Feel |
| Depth/elevation | 0.75 | Cohesion |
| Glass/translucency | 0.75 | The 2026 signature — but only where it belongs |
| Performance | 1.0 | Jank is a UX bug |
| Platform readiness | 1.0 | API 37, edge-to-edge, predictive back |

---

## 1. Color tokens (weight 1.0)

**Check**
- Surfaces, text, and containers come from `MaterialTheme.colorScheme` (or the Views equivalent
  `?attr/color*`).
- No raw `Color(0x…)` for surfaces, containers, or text.
- Tonal pairing is correct: `onX` on `X`. Never `onSurface` on `primaryContainer`.
- Dark theme exists and is not just the light scheme inverted.
- Dynamic colour is wired (`dynamicLightColorScheme` / `dynamicDarkColorScheme` on API 31+) with
  a branded fallback for API < 31.
- Containers use `surfaceContainer*` roles; `surfaceVariant` (not deprecated) is only used
  with `onSurfaceVariant` for lower-emphasis content.
- `outline` is used for meaningful boundaries, `outlineVariant` for dividers.
- Error colours are the static error role, not a red derived from the brand hue.
- Contrast levels: the app does not hard-code alpha over a translucent layer in a way that
  breaks high-contrast mode.

**Red flags**
`Color.Black.copy(alpha = 0.1f)` used as a card background; text colour set to
`MaterialTheme.colorScheme.primary` on a `primary` background; separate `LightColors.kt` and
`DarkColors.kt` files that drifted from each other.

---

## 2. Typography (weight 1.0)

**Check**
- Text uses `MaterialTheme.typography` roles, not raw `fontSize`/`fontWeight`.
- The role matches the role: screen titles use `headline*` or `title*`, body copy `body*`,
  buttons and chips `label*`.
- No text below 11sp; body text at 14sp or larger.
- Line length is sane (45–75 characters) — check for full-width paragraphs on tablets.
- Emphasized variants used deliberately for hierarchy, not everywhere.
- Custom fonts (if any) declare all weights actually used; Roboto/Roboto Flex is the default
  and is correct on Android.
- Numbers in tables/amounts use a tabular/aligned treatment if they change in place.

**Red flags**
`fontSize = 14.sp` inline; `Text("...")` with a raw `sp`; 10sp captions; all-caps labels
without letter-spacing; custom font loaded without a `FontWeight` fallback.

---

## 3. Shape (weight 0.75)

**Check**
- Shapes come from `MaterialTheme.shapes` (or `?attr/shapeAppearance*`).
- Buttons, chips, FABs, toggles use `full`.
- Cards `medium`; sheets/dialogs `extraLarge`; menus `small`.
- The corner scale is consistent within a screen — not 12dp cards next to 4dp containers for no
  reason.
- Expressive `largeIncreased` / `extraLargeIncreased` are used for the 1–2 hero moments
  (available from material3 1.5.0-beta01; on 1.4.0 they are `internal`, so score N/A).
- Icon containers and avatars match the radius of the surface they sit on.
- Shape morphing, where present, is spring-animated, not a hard swap.

**Red flags**
`RoundedCornerShape(10.dp)` written inline; 4dp everything (MD2 leftovers); a 24dp card next
to a 48dp FAB with no hierarchy rationale.

---

## 4. Motion (weight 0.75)

**Check**
- Component state animations come from Material3 (they are spring-based by default).
- Custom animations use `MaterialTheme.motionScheme` specs, not hardcoded `tween(300)`.
- Spatial specs animate geometry; effects specs animate colour/alpha.
- Enter/exit transitions use the emphasized easing set (500/400/200ms).
- Reduced motion is honoured: when the system animation scale is 0, transitions are instant.
- No animation blocks interaction, and no layout jump on the first frame.
- Long lists use `animateItem()`/`Modifier.animateItem()` for reordering, not ad-hoc animations.

**Red flags**
`animateFloatAsState` with `tween` for a card's corner radius; `Crossfade` for a simple
visibility toggle; an infinite animation that ignores the animation scale.

---

## 5. Depth / elevation (weight 0.75)

**Check**
- Depth is communicated by **tonal surface**, not by shadows.
- `Surface(tonalElevation = …)` is used instead of manually coloured containers.
- Shadows appear only where an element needs separation from a busy background (e.g. a card
  over a photo).
- Layers are consistent: page → container → raised container → overlay.
- Overlays (dialogs, menus) use the `surfaceContainerHigh*` roles, not `surface`.
- If glass is used, it is the depth treatment for *chrome* — and the tonal model still governs
  everything else.

**Red flags**
`Modifier.shadow(8.dp, RoundedCornerShape(16.dp))` on every card; a menu drawn in `surface`
instead of a raised role; a FAB that has both a shadow and a tonal overlay.

---

## 6. Components (weight 1.5)

**Check**
- Every interactive element is a Material3 component, not a `Box` with a `clickable`.
- The right component for the job: `Button` (not a `Text` with a click), `Card` (not a
  `Surface` + `Column`), `ListItem` (not a `Row` of `Icon` + `Text`).
- Button emphasis follows the ladder: exactly one filled primary action per region.
- Expressive components are used where they add value: `ButtonGroup`, `SplitButton`,
  `LoadingIndicator`, `ToggleButton` (1.5.0-beta01+); `SegmentedButton`, `Carousel`,
  `ShortNavigationBar`, `WideNavigationRail`, `SearchBar` (1.4.0+).
- Component states are complete: hover, focus, pressed, disabled, error, loading.
- Icons come from Material Symbols and have a `contentDescription` when icon-only.
- Snackbar is used for transient feedback; no custom toast overlays.
- Empty states, loading states, and error states exist and are designed.

**Red flags**
Custom `RippleEffect` or `Canvas`-drawn buttons; a `FloatingActionButton` with a raw `Box` icon;
tapping a `Text` to navigate; no loading or empty state for any async surface.

---

## 7. Layout & adaptive (weight 1.25)

**Check**
- The layout responds to window size classes (Compact / Medium / Expanded / Large).
- `NavigationSuiteScaffold` or equivalent picks bar vs rail vs drawer by width.
- Multi-pane layouts (list–detail) are used on Medium+ where the content benefits.
- On Large/Extra-large, content is width-constrained (840–1040dp) — not stretched.
- Edge-to-edge is handled: `enableEdgeToEdge()`, `Scaffold` `contentPadding`, `WindowInsets`,
  IME insets correct.
- No content is placed across a foldable hinge.
- Touch targets ≥ 48dp; spacing follows the 8dp grid.
- Landscape and split-screen are usable.
- Scroll containers use the scaffold's `contentPadding` rather than `Modifier.padding` so
  content scrolls under the bars.

**Red flags**
A hardcoded `NavigationBar` on a tablet; `Modifier.fillMaxWidth()` paragraphs on a desktop
window; a fixed `height(800.dp)`; `statusBarsPadding()` scattered instead of insets.

---

## 8. Navigation (weight 1.25)

**Check**
- The navigation model is canonical for the size class.
- Top-level destinations: 3–5 on a bottom bar.
- The current destination is always visible and obvious.
- Back behaviour is correct: system back, predictive back, and deep links.
- `NavHost` uses the right transition for the platform (expressive uses shared-axis/emphasized
  transitions, not the old slide).
- Every destination is reachable in ≤ 2 taps from the top level.
- Navigation state survives process death and configuration change.
- There is one obvious primary action per screen.

**Red flags**
A drawer on a phone with 2 destinations; a bottom bar with 6 items; a custom back button
that shadows the system one; no predictive-back handling on custom transitions.

---

## 9. Glass / translucency (weight 0.75)

**Check**
- Glass appears only in the placement tiers (`SKILL.md` §4): chrome first, media second, never
  over content the user reads.
- Every glass surface has an opaque fallback.
- Text on glass meets contrast in light and dark.
- The reduce-transparency preference is honoured.
- Nearby glass surfaces are merged into a group rather than stacked.
- The number of glass surfaces per screen is small (≤ 3 on the busiest screen).
- Blur is not applied to a form, a text list, or a reading surface.
- The effect's source does not contain the effect.

**Red flags**
`Modifier.blur()` used as a backdrop; every card is glass; a glass sheet whose body text
sits directly on blurred content; a glass layer with no fallback for when the system disables
blur.

---

## 10. Accessibility (weight 1.5)

**Check**
- Text contrast ≥ 4.5:1; large text and non-text indicators ≥ 3:1 — **including over glass**.
- Touch targets ≥ 48dp.
- Every icon-only control has a `contentDescription`; decorative icons have `null`.
- TalkBack order follows the visual order; custom semantics are correct.
- Headings are marked as headings.
- Font scale 2.0 does not clip or truncate; layout wraps or scrolls.
- The system animation scale is respected (reduced motion).
- Colour is never the only carrier of meaning.
- Content descriptions are localised and describe the *action*, not the icon name.
- `Modifier.semantics` / `stateDescription` for custom controls (e.g. a custom slider).

**Red flags**
`contentDescription = ""`; a 32dp icon button; `Icon(...)` without a description on an
interactive control; text in a fixed-height box that clips at 200% font scale; a custom
gesture with no accessible alternative.

---

## 11. Performance (weight 1.0)

**Check**
- No layout thrash: stable keys in lazy lists, `derivedStateOf` for expensive derived values.
- Compose is not re-composing whole screens on every frame (state read at the right level).
- Images are appropriately sized and cached; `AsyncImage` with a placeholder.
- No unnecessary recomposition from unstable parameters; `remember`/`rememberUpdatedState` used
  in hot paths.
- Blur/glass surfaces are capped and use a sane performance mode.
- Startup: no heavy work on the main thread; `BaselineProfile` present for release.
- Frame timing: jank below 5% on a mid-range device during scroll and animation.

**Red flags**
A `Column` inside a `LazyColumn` item without `key`; a large `List` re-read on every
recomposition; `Glide`/`Coil` loading full-resolution bitmaps into list rows; blur applied to
full-screen scrolling content.

---

## 12. Platform readiness (weight 1.0)

**Check**
- `compileSdk` / `targetSdk` are current (37 for Android 17); `targetSdk` bump is a deliberate
  decision, not an accident.
- `minSdk` is a deliberate decision with a migration note.
- Edge-to-edge is enabled and correct.
- Predictive back is supported.
- Notification and permission flows match the current platform templates.
- The app behaves on a foldable and on a tablet.
- New platform behaviours (Android 17 background changes, restrictions) are reviewed.
- The app declares correct `android:enableOnBackInvokedCallback` / uses the Compose back API.

**Red flags**
`targetSdk` several versions behind with no reason; `android:fitsSystemWindows` hacks; no
predictive-back support; hardcoded status bar colour assumptions.

---

## Reporting

Produce one report per app (not per screen). Structure it as:

1. **Summary** — overall score, the 5 highest-impact defects, the estimated effort.
2. **Screen matrix** — the table from `SKILL.md` §3 Phase 1.
3. **Critical issues** — score 0–3, with `file:line` and a concrete fix.
4. **Warnings** — score 4–6, with a recommendation.
5. **Passing** — score 7–10, noted so the upgrade does not regress it.
6. **Workstreams** — the ordered plan from Phase 2, with acceptance criteria.
7. **Not doing** — explicitly out of scope, with the reason. This prevents scope creep and
   gives the user a decision point.

Copy the skeleton from `assets/templates/audit-report.md`.

## Quick static checks

```bash
# Raw colours in Compose
rg -n 'Color\(0x' --glob '*.kt'

# Hardcoded dimensions
rg -n '\b\d+\.dp\b' --glob '*.kt' | rg -v '(1|2|4|8|12|16|24|32|48|56|64|72|96)\.dp'

# MD2 left behind
rg -n 'com\.google\.android\.material' --glob '*.kt'
rg -n 'Theme\.MaterialComponents' --glob '*.xml'

# Containers that should use a surfaceContainer* role
rg -n 'containerColor\s*=\s*MaterialTheme\.colorScheme\.surface' --glob '*.kt'

# Blur used as a backdrop (wrong mechanism)
rg -n '\.blur\(' --glob '*.kt'

# Legacy motion
rg -n 'tween\(|LinearEasing|CubicBezierEasing' --glob '*.kt'

# Missing content descriptions on icons
rg -n 'Icon\(\s*$' --glob '*.kt' -A2 | rg -v 'contentDescription'

# Hardcoded strings
rg -n 'Text\("' --glob '*.kt'

# Legacy window flags
rg -n 'FLAG_FULLSCREEN|statusBarColor' --glob '*.kt'
```

The bundled `scripts/scan_ui.py` automates most of this and adds SDK/dependency detection.
