# Tokens & colour

The foundation of the upgrade. If the token layer is wrong, nothing above it can be right.

---

## 1. The token contract

Three token systems. All three must be driven from one theme.

| System | Compose | Views | Web |
|---------|---------|-------|-----|
| Colour | `MaterialTheme.colorScheme` | `?attr/colorPrimary`, `?attr/colorSurface`, … | `--md-sys-color-*` |
| Typography | `MaterialTheme.typography` | `?attr/textAppearance*` | `--md-sys-typescale-*` |
| Shape | `MaterialTheme.shapes` | `?attr/shapeAppearance*` | `--md-sys-shape-corner-*` |

**Never** hardcode a colour, a corner radius, or a text style in a screen. If a value appears
twice, it is a token.

---

## 2. Colour roles

### Light scheme

| Role | Purpose |
|------|---------|
| `primary` | High-emphasis fills and text on surface (FAB, active states) |
| `onPrimary` | Content on `primary` |
| `primaryContainer` | Standout fill for key components |
| `onPrimaryContainer` | Content on `primaryContainer` |
| `secondary` | Less prominent accent (filter chips) |
| `onSecondary` / `secondaryContainer` / `onSecondaryContainer` | |
| `tertiary` | Contrasting accent; use to balance primary + secondary |
| `onTertiary` / `tertiaryContainer` / `onTertiaryContainer` | |
| `error` / `onError` / `errorContainer` / `onErrorContainer` | Static error palette; do not derive from the brand hue |
| `surface` | Page background |
| `onSurface` | Content on `surface` |
| `onSurfaceVariant` | Lower-emphasis content |
| `surfaceContainerLowest` | Most recessed container (dialogs) |
| `surfaceContainerLow` | Nav bar, recessed surfaces |
| `surfaceContainer` | Default container (cards, sheets) |
| `surfaceContainerHigh` | Menus, popups |
| `surfaceContainerHighest` | Most elevated container |
| `surfaceDim` / `surfaceBright` | Brightness anchors |
| `inverseSurface` / `inverseOnSurface` / `inversePrimary` | Snackbar, inverted contexts |
| `outline` | Important boundaries (text field borders) |
| `outlineVariant` | Dividers, decorative separators |
| `scrim` | Modal scrims |

### The `surfaceVariant` trap

`surfaceVariant` is **deprecated** in Material3 Expressive. It became `surfaceContainerHigh`.
Leaving it in place means a screen that looks right in one theme and wrong in another.

### Tonal pairing

Only combine a role with its `on` counterpart:

```
primary        + onPrimary             ✓
primaryContainer + onPrimaryContainer  ✓
surface        + onSurface             ✓
surfaceVariant + onSurfaceVariant      ✗  (and surfaceVariant is deprecated)
primary        + onSurface             ✗
```

`onSurface` on `primary` happens to pass contrast in some schemes and fails in others, because
dynamic colour changes the primary hue. It will break for some users.

### Contrast levels

Android exposes three contrast levels (standard / medium / high), surfaced through the
platform theme. Do not fight it:

- Don't use `alpha` to create "subtle" text — use `onSurfaceVariant`.
- Disabled content may use an `onX` colour with alpha, per the spec.
- Translucent scrims (e.g. `Color.Black.copy(alpha = 0.4f)`) are acceptable over imagery;
  over surfaces, use the `scrim` role.

---

## 3. Dynamic colour

```kotlin
val colorScheme = when {
    dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
        if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
    darkTheme -> DarkColorScheme
    else -> LightColorScheme
}
```

Rules:

- **Always provide a branded fallback** for API < 31 — the app must not look broken on an
  Android 11 device.
- **Dynamic colour applies to the primary palette**, not to error colours or to surfaces the
  user needs for legibility.
- If the brand has hard requirements (e.g. a bank app that must look like its brand), set
  `dynamicColor = false` and say so in the audit. It is a legitimate product decision, not a
  bug.
- Test the app with an extreme wallpaper hue. Some hues produce a `primary` that collides with
  `error`; components must not rely on colour alone to signal errors.
- Material Theme Builder (https://m3.material.io/theme-builder) generates the Compose theme
  code from your brand colours — use it to produce `Color.kt` and `Theme.kt` correctly rather
  than hand-writing the palette.

---

## 4. Shape tokens

| Token | Value | Use |
|-------|-------|-----|
| `none` | 0dp | — |
| `extraSmall` | 4dp | Chips, snackbars |
| `small` | 8dp | Text fields, menus |
| `medium` | 12dp | Cards |
| `large` | 16dp | FABs, nav drawer |
| `largeIncreased` | 20dp | Expressive emphasis |
| `extraLarge` | 28dp | Dialogs, bottom sheets |
| `extraLargeIncreased` | 32dp | Expressive emphasis |
| `extraExtraLarge` | 48dp | Expressive, oversized surfaces |
| `full` | 9999dp | Buttons, chips, badges, FABs, toggles |

Shape carries meaning in MD3:

- **Pill (full)** = interactive, tappable, compact.
- **Medium** = content container.
- **Large** = floating or large interactive.
- **Extra large** = modal / overlay.

Consistency matters more than any single value: a screen where every container is 4dp or
where cards are 12dp and sheets are 28dp for no reason reads as accidental.

**Views equivalent:** `?attr/shapeAppearanceCornerSmall|Medium|Large|ExtraLarge`, plus
`shapeAppearanceOverlay` for overlays.

---

## 5. Spacing

MD3 Expressive uses an 8dp grid.

| Step | Value | Typical use |
|------|-------|-------------|
| 0 | 0dp | — |
| 1 | 4dp | Icon–label gaps, tight internal padding |
| 2 | 8dp | Between related items |
| 3 | 12dp | Card internal padding (compact) |
| 4 | 16dp | Screen horizontal margin, card padding |
| 6 | 24dp | Between sections |
| 8 | 32dp | Between major blocks |
| 12 | 48dp | Between major sections on large screens |

Rules:

- Screen horizontal margin: 16dp on compact, 24dp on medium, 32–48dp on expanded.
- Pair spacing with shape: a 32dp-radius surface wants ≥ 24dp of breathing room around it.
- Don't invent a 10dp or 18dp gap. If a layout needs it, the spacing scale is wrong, not the
  layout.

---

## 6. Typography tokens

| Scale | Large | Medium | Small |
|-------|-------|--------|-------|
| Display | 57/64 | 45/52 | 36/44 |
| Headline | 32/40 | 28/36 | 24/32 |
| Title | 22/28 | 16/24 | 14/20 |
| Body | 16/24 | 14/20 | 12/16 |
| Label | 14/20 | 12/16 | 11/16 |

(size/line-height in sp)

Role selection:

- **Display** — numbers that change in place, hero metrics. Rare.
- **Headline** — screen titles, section headers.
- **Title** — card titles, list item headlines, app bar titles.
- **Body** — paragraphs, descriptions, supporting text.
- **Label** — button labels, chips, captions, nav labels.

Emphasized variants (higher weight) exist for every role. Use them for the single most
important element in a group, not as a default.

**Roboto / Roboto Flex is the correct default typeface on Android.** If a "frontend design"
skill tells you to avoid Roboto, ignore that for Android targets.

---

## 7. The glass tint strategy

Glass needs a **colour** to be legible. This is the single most important rule for the
frosted layer.

| Glass role | Tint colour | Notes |
|-----------|-------------|-------|
| App bar over content | `surfaceContainer` @ ~70 % + white/black tint | Keeps text on `onSurface` readable |
| Bottom nav | `surfaceContainer` @ ~80 % | Slightly more opaque than the app bar — it carries more text |
| FAB | Keep the FAB's own M3 colour (`primaryContainer` etc.) | Do not glass the FAB's label |
| Segmented control | `surfaceContainerHigh` @ ~60 % | Grouped, so merge into one glass cluster |
| Sheet header | `surfaceContainerLow` @ ~90 % | The sheet body stays fully opaque |
| Media overlay | `surface` @ 40 % + a scrim | Over photos/video, always add a scrim |

Implementation: never hardcode these alphas. Derive them:

```kotlin
val glassStyle = GlassStyle.regular.material3(
    containerColor = MaterialTheme.colorScheme.surfaceContainer,
    tint = Color.White.copy(alpha = 0.12f),   // white in light; use black in dark
)
```

For dark theme, use a black tint; for light, white. Derive it:

```kotlin
val tint = if (isSystemInDarkTheme()) Color.Black.copy(alpha = 0.20f)
           else Color.White.copy(alpha = 0.16f)
```

**Contrast rule:** the text on glass must still reach 4.5:1 (3:1 for large text). If it does
not, increase the container alpha — do not lighten the text.

---

## 8. Token anti-patterns

| Anti-pattern | Why | Instead |
|--------------|-----|---------|
| `Color(0xFF…)` in a composable | Breaks dark mode + dynamic colour | A `colorScheme` role |
| A local `val MyColors = object { … }` | Second source of truth | Theme tokens |
| `Color.Black.copy(alpha = 0.05f)` as a card | Alpha stacking breaks contrast | `surfaceContainer*` |
| `elevation = 8.dp` to mean "important" | Elevation is not emphasis | Colour role + type role |
| `sp` sizes written inline | Breaks the scale | `MaterialTheme.typography.*` |
| `RoundedCornerShape(13.dp)` | Off-scale | A shape token |
| `TextUnit` overrides for one screen | Drift | Custom `TextStyle` in the theme, referenced by role |
| Hardcoded glass alpha | Breaks dark mode | Derive from the theme + appearance |
