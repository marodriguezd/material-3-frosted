# Material 3 Expressive — the Layer A system

Material 3 Expressive is an expansion of Material 3, not a redesign: it keeps MD3's tokens and
usability rules and adds **shape, motion, colour and typography** that carry meaning. It is the
target design language for apps on Android 16/17.

## Version gate — read first

Verified against the published artifacts:

| API | 1.4.0 (stable) | 1.5.0-beta01 |
|-----|----------------|--------------|
| `MaterialExpressiveTheme` | **`internal`** | `public` |
| `MotionScheme.expressive()` / `.standard()` | **`internal`** | `public` |
| `Shapes.largeIncreased` / `extraLargeIncreased` / `extraExtraLarge` | **`internal`** | `public` |
| `ButtonGroup`, `SplitButton`, `ToggleButton`, `LoadingIndicator` | absent | `public` |
| `FloatingToolbar`, `FloatingActionButtonMenu`, `WavyProgressIndicator`, `ScrollField` | absent | `public` |
| `ShortNavigationBar`, `WideNavigationRail`, `SegmentedButton`, `Carousel`, `SearchBar` | `public` | `public` |

Everything below assumes **`androidx.compose.material3:material3:1.5.0-beta01`** or newer. The
Compose BOM `2026.09.00` pins 1.4.0, so you must override `material3` explicitly. If the project
cannot take a beta, stay on 1.4.0 and use only the components listed as `public` there — a plain
`MaterialTheme` plus `SegmentedButton` / `Carousel` / `ShortNavigationBar` / `WideNavigationRail`
is still a large, real improvement.

---

## 1. The three principles and how to apply them

| Principle | Meaning | Concrete action |
|-----------|---------|-----------------|
| **Personal** | Dynamic colour adapts to the user's wallpaper | `dynamicLightColorScheme` / `dynamicDarkColorScheme` on API 31+, with a branded fallback |
| **Adaptive** | Layouts transform across window size classes | `currentWindowAdaptiveInfo()`, `NavigationSuiteScaffold`, `ListDetailPaneScaffold` |
| **Expressive** | Shape, spring motion, emphasized type create moments | `MotionScheme.expressive()`, expressive shapes, emphasized type |

---

## 2. Theme

```kotlin
MaterialExpressiveTheme(
    colorScheme = colorScheme,
    motionScheme = MotionScheme.expressive(),
    shapes = Shapes(),
    typography = Typography(),
    content = content,
)
```

`MaterialExpressiveTheme` is public from Material3 1.5.0-beta01 (in 1.4.0 it is `internal`). It
needs no opt-in annotation. It is the same as `MaterialTheme` plus a `motionScheme` parameter,
and it defaults to the expressive motion scheme when you omit it.

### Colour scheme

```kotlin
val context = LocalContext.current
val colorScheme = when {
    dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
        if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
    darkTheme -> darkColorScheme()
    else -> lightColorScheme()
}
```

**`surfaceVariant` vs the `surfaceContainer*` family:** `surfaceVariant` is still a valid M3
role and is **not** deprecated. Expressive added `surfaceContainerLowest` …
`surfaceContainerHighest` for containers that should carry the elevation tint explicitly;
prefer those for cards, menus and sheets, and keep `surfaceVariant` where the design already
uses it (it is the right pairing for `onSurfaceVariant`).

| Role | Use |
|------|-----|
| `surface` | Page background |
| `surfaceContainerLowest` | The most recessed container (dialogs) |
| `surfaceContainerLow` | Nav bar, recessed cards |
| `surfaceContainer` | Default raised container (cards, sheets) |
| `surfaceContainerHigh` | Menus, popups |
| `surfaceContainerHighest` | The most elevated container |
| `surfaceDim` / `surfaceBright` | Brightness anchors across light/dark |
| `outline` | Important boundaries (text field borders) |
| `outlineVariant` | Dividers, decorative separators |

### Typography

15 roles, plus **emphasized** variants (heavier weight) for the same roles. Use the scale; don't
invent sizes.

| Scale | Large | Medium | Small |
|-------|-------|--------|-------|
| Display | 57/64 | 45/52 | 36/44 |
| Headline | 32/40 | 28/36 | 24/32 |
| Title | 22/28 | 16/24 | 14/20 |
| Body | 16/24 | 14/20 | 12/16 |
| Label | 14/20 | 12/16 | 11/16 |

Labels are Medium weight; titles are Regular at their base size. The **emphasized** variants
(for example emphasized `titleLarge`, 22sp/28sp) are SemiBold — use those for the one hero
moment per screen, not for every title.

### Shapes

| Token | Value | Typical use |
|-------|-------|-------------|
| `none` | 0dp | — |
| `extraSmall` | 4dp | Chips, snackbars |
| `small` | 8dp | Text fields, menus |
| `medium` | 12dp | Cards |
| `large` | 16dp | FABs, nav drawer |
| `largeIncreased` | 20dp | **Expressive** — emphasized surfaces (1.5.0-beta01+) |
| `extraLarge` | 28dp | Dialogs, bottom sheets |
| `extraLargeIncreased` | 32dp | **Expressive** — hero moments (1.5.0-beta01+) |
| `extraExtraLarge` | 48dp | **Expressive** — oversized surfaces (1.5.0-beta01+) |
| `full` | 9999dp | Buttons, chips, badges |

Buttons, chips, FABs, and toggle buttons use `full`. Cards use `medium`. Sheets and dialogs use
`extraLarge`. Use `largeIncreased` / `extraLargeIncreased` for the 1–2 hero moments per flow.

`Shapes` is a class with a public constructor from 1.5.0-beta01. Override the whole scale so the
increased tokens stay coherent with the rest:

```kotlin
val expressiveShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(28.dp),
    largeIncreased = RoundedCornerShape(20.dp),
    extraLargeIncreased = RoundedCornerShape(32.dp),
    extraExtraLarge = RoundedCornerShape(48.dp),
)
```

On 1.4.0, only the five base tokens exist publicly — defining an expressive set there means
using `large`/`extraLarge` and accepting the larger radii on cards and sheets.

---

## 3. Motion

### Motion scheme

`MotionScheme` exposes six spring specs:

| Spec | Use |
|------|-----|
| `defaultSpatialSpec()` | Changes shape or bounds |
| `fastSpatialSpec()` | Quick shape/bounds change (press, expand) |
| `slowSpatialSpec()` | Deliberate, large shape change |
| `defaultEffectsSpec()` | Colour, alpha, non-spatial |
| `fastEffectsSpec()` | Quick colour/alpha |
| `slowEffectsSpec()` | Deliberate colour/alpha |

```kotlin
val shape by animateDpAsState(
    targetValue = if (expanded) 32.dp else 16.dp,
    animationSpec = MaterialTheme.motionScheme.defaultSpatialSpec(),
)
```

Rules:

- **Spatial** specs for geometry; **effects** specs for colour/alpha. Using a spatial spec for a
  colour animation makes it feel sluggish.
- Read the scheme from `MaterialTheme.motionScheme`. Do not introduce a parallel motion config;
  one source of physics for the whole app.
- Component-level animations (press, ripple, state) are already spring-driven inside Material3;
  you do not need to add your own.
- Legacy easing/duration tokens remain valid for **transitions** (enter/exit/shared-axis):

| Easing | Duration | Use |
|--------|----------|-----|
| Emphasized | 500ms | On screen → on screen |
| Emphasized decelerate | 400ms | Enter the screen |
| Emphasized accelerate | 200ms | Exit the screen |
| Standard | 300ms | On screen → on screen (utility) |
| Standard decelerate | 250ms | Enter screen (utility) |
| Standard accelerate | 200ms | Exit screen (utility) |

### Shape morphing

Expressive shape morphing animates a shape between states rather than swapping one rounded
rect for another.

For simple cases, animate the corner radius with a spatial spring:

```kotlin
val corner by animateDpAsState(
    targetValue = if (selected) 28.dp else 16.dp,
    animationSpec = MaterialTheme.motionScheme.defaultSpatialSpec(),
)
Surface(shape = RoundedCornerShape(corner)) { … }
```

For expressive morphs, `androidx.graphics.shapes` gives you `RoundedPolygon` and `Morph`:

```kotlin
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
val path = MaterialShapes.Squircle.toShape()   // a RoundedPolygon-backed Shape
```

`MaterialShapes` ships a catalogue of normalised polygons — `Circle`, `Square`, `Slanted`,
`Arch`, `Fan`, `Arrow`, `SemiCircle`, `Oval`, `Pill`, `Triangle`, `Diamond`, `ClamShell`,
`Pentagon`, `Gem`, `Sunny`, `VerySunny`, `Cookie4Sided`…`Cookie12Sided`, `Ghostish`,
`Clover4Leaf`, `Clover8Leaf`, `Burst`, `SoftBurst`, `Boom`, `SoftBoom`, `Flower`, `Puffy`,
`PuffyDiamond`, `PixelCircle`, `PixelTriangle`, `Bun`, `Heart` — plus `Morph.toPath(progress)`
to animate between them. These are `@ExperimentalMaterial3ExpressiveApi`.

**Budget shape morphs.** Morphing is expressive because it is rare. A screen where every
container morphs is noise.

---

## 4. Components

### New / refreshed in Expressive

Availability column is the **minimum material3 version**, verified against the artifacts.

| Component | Available | Notes |
|-----------|-----------|-------|
| `AppBarRow` / `AppBarColumn` | 1.4.0 | The expressive app-bar layouts; replace `TopAppBar` in composite headers |
| `ShortNavigationBar` | 1.4.0 | The expressive (shorter) bottom bar; `ShortNavigationBarItem` |
| `WideNavigationRail` | 1.4.0 | Expanded-width rail; `WideNavigationRailState` |
| `SegmentedButton` | 1.4.0 | `SingleChoiceSegmentedButtonRow` / `MultiChoiceSegmentedButtonRow` |
| `Carousel` | 1.4.0 | `HorizontalMultiBrowseCarousel`, `HorizontalUncontainedCarousel` |
| `SearchBar` | 1.4.0 | Expanded / docked search |
| `ButtonGroup` | 1.5.0-beta01 | `ButtonGroupScope`, `ButtonGroupDefaults`, overflow menu state |
| `SplitButton` | 1.5.0-beta01 | `SplitButtonLayout` + `SplitButtonDefaults.LeadingButton` / `.TrailingButton` |
| `ToggleButton` | 1.5.0-beta01 | Plus `FilledTonalToggleButton`, `ElevatedToggleButton`, `OutlinedToggleButton` |
| `LoadingIndicator` | 1.5.0-beta01 | The new indeterminate loader; `ContainedLoadingIndicator` |
| `WavyProgressIndicator` | 1.5.0-beta01 | Expressive determinate progress |
| `FloatingToolbar` | 1.5.0-beta01 | Contextual toolbar |
| `FloatingActionButtonMenu` | 1.5.0-beta01 | FAB that expands into a menu |
| `ScrollField` | 1.5.0-beta01 | Scrolling field |
| `VibrantTimePickerDialog` | 1.5.0-beta01 | The vibrant time-picker dialog |
| `SelectableDropdownMenuItem` / `CheckableDropdownMenuItem` | 1.5.0-beta01 | Menu variants |
| `NavigationSuiteScaffold` | adaptive-navigation-suite | Bar / rail / drawer, chosen by width |

### Button emphasis

Use the emphasis ladder below and **one** filled primary action per region. Expressive UI
usually has *fewer* filled buttons, not more; the visual interest comes from shape and motion,
not from filling everything.

### Emphasis ladder

```
FloatingActionButton  →  Button (filled)  →  ElevatedButton  →  FilledTonalButton  →  OutlinedButton  →  TextButton
```

Use exactly one filled primary action per screen region. Expressive UI usually has **fewer**
filled buttons, not more.

---

## 5. Layout & adaptive

### Window size classes

| Class | Width | Canonical layout |
|-------|-------|------------------|
| Compact | < 600dp | Single pane, bottom nav bar |
| Medium | 600–839dp | Two panes, nav rail |
| Expanded | 840–1199dp | Two/three panes, nav rail or drawer |
| Large | 1200–1599dp | Multi-pane, max content width ~1040dp |
| Extra large | ≥ 1600dp | Multi-pane, max content width ~840–1040dp |

```kotlin
val adaptiveInfo = currentWindowAdaptiveInfo()
val layoutType = adaptiveInfo.windowSizeClass.windowWidthSizeClass
```

### Navigation suite

`NavigationSuiteScaffold` from `androidx.compose.material3:material3-adaptive-navigation-suite`
picks the right navigation surface for the width — bottom bar on compact, rail on medium, drawer
on expanded — and handles the transition. This replaces hand-rolled "if width > 600 use rail"
logic.

### Canonical layouts

- **List–detail** (`ListDetailPaneScaffold`): feed + detail, detail on a second pane.
- **Supporting pane**: main task + secondary context.
- **Feed**: single scrolling column, full width.

On large screens, constrain content to a readable max width (~840–1040dp). Never let a
paragraph stretch to 1600dp.

### Foldables

Use `androidx.compose.material3.adaptive` posture info to avoid placing interactive content
across the hinge. Test in the foldable emulator.

### Spacing

Use an 8dp grid: 4, 8, 12, 16, 24, 32, 48. Expressive layouts are more generous with spacing
than MD2 — the extra room is part of the look. Pair spacing with shape: bigger radii want
bigger gaps.

### Edge-to-edge

Android 15+ (API 35) draws apps edge-to-edge by default; Android 16/17 continues this.

```kotlin
// Activity
enableEdgeToEdge()

// Compose
Scaffold { padding ->
    LazyColumn(contentPadding = padding) { … }   // padding as contentPadding, not modifier.padding
}
```

Use `WindowInsets` and `Scaffold`'s `contentPadding` so bars and the IME behave. See
`references/migration-playbook.md` § Edge-to-edge.

---

## 6. Hero moments

A **hero moment** is a single, deliberate expression — a shape morph, a spring transition, an
emphasized type scale, a colour burst.

Rules:

- **1–2 per flow**, never per screen. A flow with 10 hero moments has none.
- Pick by importance: the screen's single most important action or piece of information.
- A hero moment must not cost legibility, accessibility, or performance.
- Common choices: a FAB that morphs into a sheet, a card that expands to fill the screen, a
  loading indicator that morphs into content, a segmented control that slides.

---

## 7. Expressive intensity levels

Choose one per feature and keep it consistent.

| Level | Meaning | Typical app |
|-------|---------|-------------|
| **Foundational** | Correctness and familiarity first; expressive only where free | Utilities, enterprise, most apps |
| **Excellent** | Stronger colour, type and shape while preserving all standard patterns | Consumer apps with a brand |
| **Transformative** | Bold layout and motion, strict usability and accessibility rules | Showcase, media, launchers |

**Default to Foundational** unless the user asks for a bolder treatment. Expressive is a means,
not the goal.

---

## 8. What is *not* Expressive

- The frosted-glass look is **not** part of M3 Expressive. It is a separate depth treatment
  (see `references/glass-effects.md`). MD3 Expressive's own depth model is **tonal surfaces**.
- MD2 patterns (raised buttons, filled text fields with a hard underline, monochrome app bars,
  `TabLayout` with a hairline) are not expressive — they are legacy.
- Material Web (`@material/web`) is in **maintenance mode** and does **not** implement
  Expressive. Do not promise web parity.

---

## 9. Flutter and other stacks

| Capability | Flutter | Web |
|-----------|---------|-----|
| Expressive motion (springs) | Varies by Flutter version; `Spring` curves | **Not** available — use easing/duration |
| Emphasized typography | Theme `TextTheme` | CSS custom properties only |
| Shape morphing | Custom `Shape`/`Path` animation | Limited |
| Expressive components | Check current Flutter Material | Not available |
| Frosted glass | `BackdropFilter` (Flutter) / `backdrop-filter` (CSS) — **not** the same APIs | |

Flutter equivalent of the glass layer: `BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24))`
over a `ClipRRect`. There is no refraction/Glass equivalent in Flutter's framework — treat
Flutter glass as blur-only, and expect a different visual result from the Compose app.
