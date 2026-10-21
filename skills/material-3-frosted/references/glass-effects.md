# Frosted glass & translucency on Android

Everything needed to add a credible, performant, accessible frosted-glass layer to an Android
app. Read §1 before writing any code: most failed glass implementations pick the wrong
mechanism.

---

## 1. Choose the right mechanism

There are **four** distinct mechanisms. They are not interchangeable.

| Mechanism | Blurs what | When to use | Cost |
|-----------|-----------|-------------|------|
| **A. `Modifier.blur()`** (Compose) | The composable's **own** content | Blurring an image (a cover photo, a map tile). **Never** a backdrop. | Low |
| **B. Haze Blur** (`haze-blur`) | Content **behind** the surface, inside the same window | App chrome over scrolling content, glass sheets, blurred headers | Medium–High |
| **C. Haze Glass** (`haze-glass`) | Content behind, **plus** refraction, depth, specular highlight, edge | The Android 17 "liquid glass" look for controls and chrome | High |
| **D. Platform window blur** (`Window.setBackgroundBlurRadius`) | The **screen behind the window** (another app, the launcher) | Dialogs and floating windows that must blur other apps | Medium |

**The #1 mistake** is using A when you mean B. `Modifier.blur()` rasterises the node it is
applied to and blurs *that*. It cannot see what is behind it, so a "glass card" built with it is
just a blurry card.

```kotlin
// WRONG — blurs the image itself
Image(painter, modifier = Modifier.blur(24.dp))

// WRONG — blurs the card's own children, not the page behind it
Card(modifier = Modifier.blur(24.dp)) { Text("…") }

// RIGHT — Haze samples what was drawn earlier in the same window
Box(modifier = Modifier.hazeSource(hazeState)) { /* page content */ }
Surface(modifier = Modifier.hazeBlur(HazeInput.Backdrop(hazeState), style)) { /* chrome */ }
```

---

## 2. Haze 2 — module map

| Artifact | Provides | Use it when |
|----------|----------|-----------|
| `dev.chrisbanes.haze:haze` | `HazeState`, `rememberHazeState()`, `HazeInput`, `Modifier.hazeSource`, `HazeFeatureFlags`, `HazePerformanceMode`, `HazeProgressive`, `HazeSourceRetention` | Always (core) |
| `dev.chrisbanes.haze:haze-blur` | `Modifier.hazeBlur`, `HazeBlurStyle`, `LocalHazeBlurStyle` | Blur-only chrome (cheaper than Glass) |
| `dev.chrisbanes.haze:haze-blur-materials` | `HazeMaterials` (`ultraThin`/`thin`/`regular`/`thick`/`ultraThick`), `CupertinoMaterials`, `FluentMaterials` | You want presets |
| `dev.chrisbanes.haze:haze-blur-material3` | `HazeBlurStyle.Material3 { … }` | The blur should use the live M3 `surface` colour |
| `dev.chrisbanes.haze:haze-glass` | `Modifier.hazeGlass`, `GlassStyle`, `GlassOptics`, `LocalGlassStyle`, `GlassAccessibilitySettings` | You want refraction/specular "liquid glass" |
| `dev.chrisbanes.haze:haze-glass-material3` | `GlassStyle.material3 { … }` | Glass should use the live M3 `surface` colour |

All artifacts are published together — **use the same version for all of them** (`2.0.1` at
time of writing).

Packages:

| Symbol | Package |
|--------|---------|
| `HazeState`, `rememberHazeState`, `HazeInput`, `HazeSource`, `HazePerformanceMode`, `HazeProgressive`, `HazeSourceRetention`, `HazeFeatureFlags` | `dev.chrisbanes.haze` |
| `hazeBlur`, `HazeBlurStyle`, `LocalHazeBlurStyle`, `BlurredEdgeTreatment` | `dev.chrisbanes.haze.blur` |
| `HazeMaterials`, `CupertinoMaterials`, `FluentMaterials` | `dev.chrisbanes.haze.blur.materials` |
| `HazeBlurStyle.Material3` | `dev.chrisbanes.haze.blur.material3` |
| `hazeGlass`, `GlassStyle`, `GlassOptics`, `LocalGlassStyle`, `GlassAccessibilitySettings`, `LocalGlassAccessibilitySettings`, `GlassTransformTarget`, `GlassTransformPivot`, `GlassReducedMotionPolicy`, `GlassMemberTransition`, `OpticalSizeValue`, `RefractionProfile`, `SurfaceProfile` | `dev.chrisbanes.haze.glass` |
| `GlassStyle.material3` | `dev.chrisbanes.haze.glass.material3` |

---

## 3. Haze input modes

`HazeInput` decides **what** the effect samples. Picking the wrong one causes empty frames,
missing content, or a self-referencing loop.

| Input | Samples | Use when |
|-------|---------|----------|
| `HazeInput.Backdrop(state)` | All pixels already drawn earlier in the current window (native path on Android 37.2+; source-capture fallback elsewhere) | The default for app chrome. Portable. |
| `HazeInput.Sources(state, selection, retention)` | Exactly the `hazeSource` modifiers you chose | You need precise ownership, cross-window alignment, or retention control |
| `HazeInput.Content` | The modifier's own content | Blurring a node's own children (rare) |

```kotlin
val hazeState = rememberHazeState()

// Source: the scrolling content only.
LazyColumn(modifier = Modifier.fillMaxSize().hazeSource(hazeState)) { … }

// Effect: a sibling bar that samples what is behind it.
TopAppBar(
    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
    modifier = Modifier.hazeBlur(
        input = HazeInput.Backdrop(hazeState),
        style = HazeMaterials.thin(),
    ),
)
```

### The source/effect topology rule

**The source must not contain the effect.** If you mark the whole screen (including the top bar)
as a source, the bar samples itself → recursion, an empty frame, or a smear.

- Scaffold: `topBar`/`bottomBar` are **siblings** of the content lambda. Source the content;
  effect the bars.
- Sticky header inside a list: source the **items**, not the whole `LazyColumn`; effect the
  header.
- Navigation: capture the whole `NavDisplay` as the source, and put the effect-backed nav in
  `Scaffold.bottomBar` as a sibling.

### Retention (privacy)

By default an effect keeps drawing its last output when its source disappears. For
privacy-sensitive content (a photo you just deleted, a private message), clear it:

```kotlin
Modifier.hazeBlur(
    input = HazeInput.Sources(
        state = hazeState,
        retention = HazeSourceRetention.ClearWhenUnavailable,
    ),
    style = style,
)
```

---

## 4. Blur vs Glass

| | Blur (`hazeBlur`) | Glass (`hazeGlass`) |
|---|---|---|
| Model | Frosted | Liquid / refractive |
| Optics | Blur radius, noise, tint, progressive gradient, mask | Refraction with edge profile, depth, specular highlight, ambient response, dispersion, shape |
| Cost | Medium | High |
| Best for | Content scrims, blurred headers, dense chrome | Prominent controls: FAB, segmented control, nav bar, floating buttons |
| Presets | `HazeMaterials.ultraThin() … ultraThick()` | `GlassStyle.regular`, `GlassStyle.clear` |

**Start with Blur.** Move to Glass for a small number of high-prominence surfaces once the blur
layer is stable and measured. `GlassStyle.regular` diffuses the backdrop more aggressively
(chosen by surface size) and is the right default for text-bearing surfaces; `GlassStyle.clear`
keeps the background visible and suits controls over photos/video, but then you must guarantee
contrast yourself (add a dim layer).

### Blur style knobs (`HazeBlurStyle`)

```kotlin
val style = HazeBlurStyle {
    blurEnabled(true)
    blurRadius(20.dp)
    noiseFactor(0.15f)
    backgroundColor(Color.Black)
    colorEffects(listOf(HazeColorEffect.tint(Color.White.copy(alpha = 0.12f))))
    fallbackColorEffect(HazeColorEffect.tint(Color.Black.copy(alpha = 0.7f)))
    alpha(1f)
    mask(null)
    progressive(null)
    blurredEdgeTreatment(BlurredEdgeTreatment.Rectangle)
}
```

Style resolution order (last write wins):

```
HazeBlurDefaults.style  →  LocalHazeBlurStyle  →  the explicit style argument
```

Styles are immutable and cheap to derive:

```kotlin
val base   = HazeMaterials.thin()
val quiet  = base.then { noiseFactor(0f); colorEffects(emptyList()) }
val strong = base.then { blurRadius(32.dp) }
```

A replacement style that omits a property falls back to the local/default value for it.

### Glass style knobs (`GlassStyle`)

```kotlin
val style = GlassStyle.regular.then {
    backgroundColor(Color.White.copy(alpha = 0.10f))
    tint(Color.White.copy(alpha = 0.16f))
    shape(RoundedCornerShape(20.dp))
    specularIntensity(0.7f)
    ambientResponse(0.7f)
    edgeSoftness(14.dp)
    surfaceProfile(SurfaceProfile.Squircle)
    chromaticAberrationStrength(0.15f)   // keep modest: 0.1–0.25
}
```

Key defaults: `specularIntensity` 0.48, `ambientResponse` 0.15, `edgeShadow` black @ 14 %,
`edgeSoftness` 1dp, `refractionDetailIntensity` 0.76 (Regular uses 0, Clear uses 0.76),
`alpha` 1.

Optics (`GlassOptics`) are the low-level controls — `blurRadius`, `refractionStrength`,
`refractionDisplacement`, `refractionHeightFraction`, `refractionFoldStrength`, `depth`,
`refractionProfile` (`Surface` vs `Edge(width)`), and `progressive`. `GlassOptics.regular`
and `GlassOptics.clear` are the built-in configurations; the `GlassOptics()` constructor
defaults are **not** Regular's. Derive from the built-in, don't start from the constructor:

```kotlin
GlassOptics.regular.copy(
    blurRadius = OpticalSizeValue.Fixed(20.dp),
    refractionStrength = 0.8f,
)
```

### Material 3 integration

Use the M3 integration so the glass colour always tracks the live theme (dynamic colour, dark
mode, high contrast) instead of a hardcoded alpha:

```kotlin
// Blur
Modifier.hazeBlur(
    input = HazeInput.Backdrop(hazeState),
    style = HazeBlurStyle.Material3 { blurRadius(12.dp) },
)

// Glass
Modifier.hazeGlass(
    input = HazeInput.Backdrop(hazeState),
    style = GlassStyle.regular.material3(
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        tint = Color.White.copy(alpha = 0.12f),
    ),
)
```

`material3()` writes the M3 colours **first**, so the receiver style can override them. It is
`@Composable` and follows theme changes on recomposition — hoist or `remember` the result.

To apply to a whole subtree:

```kotlin
CompositionLocalProvider(LocalGlassStyle provides GlassStyle.material3()) { … }
CompositionLocalProvider(LocalHazeBlurStyle provides HazeBlurStyle.Material3()) { … }
```

### Progressive blur and masks

```kotlin
// Strong at the top, fading out (classic scrolled app bar)
val style = HazeBlurStyle {
    progressive(HazeProgressive.verticalGradient(startIntensity = 1f, endIntensity = 0f))
}

// Cheaper alternative: fade the effect's opacity
val masked = HazeBlurStyle {
    mask(Brush.verticalGradient(colors = listOf(Color.Black, Color.Transparent)))
}
```

Note: at full resolution (`HazePerformanceMode.Quality`) a *linear* progressive effect is drawn
several times and costs much more. Lower-resolution modes blend a gradient mask instead.

---

## 5. Fallbacks — the part everyone skips

Blur can disappear at any moment. Design for that.

| Cause | Signal | What to do |
|-------|--------|------------|
| Device doesn't support window blur | `windowManager.isCrossWindowBlurEnabled == false` | Use an opaque surface |
| Battery saver / system state | `isCrossWindowBlurEnabled` flips at runtime | Listen and swap |
| User's *Reduce blur effects* toggle | System stops applying blur | Provide an in-app preference and/or an opaque fallback |
| GPU too weak | System disables blurs | Opaque fallback |
| Haze native backdrop unavailable | Falls back to source capture, then to no effect | Style's `fallbackColorEffect` |

### Platform window blur (mechanism D)

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    window.setBackgroundBlurRadius(80)                 // 80px = good frosted glass
    window.addFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
    window.attributes = window.attributes.apply {
        blurBehindRadius = 20                           // 20px = good depth-of-field
    }
}
```

Guidance from AOSP: **80 px** background blur for frosted glass, **20 px** blur behind for
depth of field, and **never above 150 px** (the GPU samples a proportionally larger area, so
the cost explodes).

The window must be **translucent** for the blur to be visible, and the window background
drawable defines the rounded outline of the blurred region:

```xml
<style name="Theme.App.Dialog" parent="Theme.Material3.DayNight.Dialog">
    <item name="android:windowIsTranslucent">true</item>
    <item name="android:windowBackground">@drawable/dialog_background</item>
    <item name="android:windowBackgroundBlurRadius">80</item>
    <item name="android:windowBlurBehindEnabled">true</item>
    <item name="android:windowBlurBehindRadius">20</item>
</style>
```

```xml
<!-- res/drawable/dialog_background.xml -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <corners android:radius="28dp"/>
    <solid android:color="#22000000"/>
</shape>
```

**Always handle the disabled state.** When blurs are off, the translucent window sits directly
over the content behind it and becomes unreadable. Increase the background alpha and the dim
amount instead:

```kotlin
private fun updateWindowForBlurs(blursEnabled: Boolean) {
    backgroundDrawable.alpha = if (blursEnabled) 170 else 255
    window.setDimAmount(if (blursEnabled) 0.1f else 0.4f)
}
```

Listen for changes:

```kotlin
windowManager.addCrossWindowBlurEnabledListener { enabled -> updateWindowForBlurs(enabled) }
```

Testing: `adb shell wm disable-blur 1` (rooted) or *Developer options → Allow window-level
blurs*.

---

## 6. Accessibility

Android exposes *Settings → Accessibility → Color & motion → Reduce blur effects* (Android 16
QPR2+). **There is no public API to read that toggle.** The signal you can read is
`windowManager.isCrossWindowBlurEnabled`, which covers system-level disabling (battery saver,
user preference, hardware). For app-drawn effects (Haze), you must:

1. Provide your own in-app preference (e.g. *Settings → Display → Reduce transparency*), and/or
2. Always render a legible opaque variant of any glass surface, and
3. Map your preference to Haze's accessibility settings.

### `GlassAccessibilitySettings`

```kotlin
CompositionLocalProvider(
    LocalGlassAccessibilitySettings provides GlassAccessibilitySettings(
        reduceTransparency = reduceTransparency,   // more opaque, fully diffused blur
        increaseContrast = increaseContrast,       // higher tone contrast + visible edge
        showBorders = showBorders,                 // visible edge without tone change
    ),
) { … }
```

- `reduceTransparency` makes glass **more opaque** with a stronger, fully diffused blur (it does
  *not* reduce the blur, which would expose more of the background).
- `increaseContrast` raises tone contrast and enforces a visible edge.
- `showBorders` enforces a visible edge without changing tone.
- The defaults leave the style unchanged. These settings never modify your style values.
- `reducedTransparencyFallbackColor` overrides the opaque base used by the fallback renderer
  (white in light appearance, black in dark). Must be opaque; translucent values are rejected.

### Blur style accessibility

`HazeBlurStyle` has no accessibility object. If you need the same behaviour for blur, drive it
from the style itself: when reduced transparency is on, set an opaque `backgroundColor` and
raise the `fallbackColorEffect` alpha.

### Contrast

- Text on glass: use `onSurface` over a `surfaceContainer*`-tinted glass. Verify 4.5:1 for
  body text, 3:1 for large text and non-text.
- Glass over imagery: `GlassStyle.clear` will not guarantee contrast. Add a scrim/dim layer
  behind the content.
- Test both light and dark appearance; the system appearance (not `MaterialTheme`) drives
  Glass's light/dark response.

---

## 7. Performance

Blur and glass are GPU-expensive and they are the most common cause of jank in "modern" Android
apps.

### Rules

1. **Cap the number of glass surfaces per screen.** 2–3 is a budget, not a guideline.
2. **Prefer `HazeInput.Backdrop` over `HazeInput.Sources`** where possible: backdrop is
   cheaper and does not require capturing extra layers.
3. **Do not mark huge scrolling content as a source** if the effect only needs the top region —
   the source capture cost scales with the captured area.
4. **Avoid `expandLayerBounds = true`** (the default) on very large surfaces if you see banding
   at the edges; it expands the render layer.
5. **Use `HazePerformanceMode.Default`** (the fixed *Balanced* profile) unless you have
   measured. `Quality` is for hero surfaces; `Performance` for cheap chrome.
6. **Measure** on a mid-range device with a release build. A debug build tells you nothing.
7. **Each glass surface is its own layer.** Haze 2.0.1 has no clustering API — `hazeGlassContainer`
   is on Haze's `main` branch, not in the released artifact, so it will not compile. The lever
   you have is the count: keep a group of glass controls to 2–3 members.

### Performance modes

```kotlin
Modifier.hazeBlur(
    input = HazeInput.Backdrop(hazeState),
    style = style,
    performanceMode = HazePerformanceMode.Default,   // == Balanced profile
)
```

`HazePerformanceMode` offers `Default` (Balanced), `Quality`, `Performance`, and
`Fixed(...)` for explicit control. `Adaptive` is a deprecated alias for `Default`.

### Interaction

Glass interaction is **opt-in and purely visual** — it adds no click handling, focusability, or
semantics. To get press/focus lighting, share a remembered `MutableInteractionSource` between the
Glass modifier and your behaviour modifiers:

```kotlin
val interactionSource = remember { MutableInteractionSource() }

Modifier
    .clickable(interactionSource = interactionSource, indication = null) { onClick() }
    .focusable(interactionSource = interactionSource)
    .hazeGlass(
        input = HazeInput.Backdrop(hazeState),
        style = interactionStyle,
        interactionSource = interactionSource,
        interactionTransformTarget = GlassTransformTarget.MaterialAndContent,
        interactionTransformPivot = GlassTransformPivot.Pointer,
        interactionReducedMotionPolicy = GlassReducedMotionPolicy.System,
    )
```

`GlassReducedMotionPolicy.System` follows the system animation scale and becomes `Reduced`
(scale = 0). `Reduced` snaps lighting and optics and suppresses transforms. `Full` always
animates.

---

## 8. Native Android window backdrop (experimental)

Android 37.2+ exposes a native compositor backdrop path. Haze can use it, but it is
**opt-in, experimental, and not guaranteed**:

```kotlin
// Set process-wide, BEFORE the effect nodes attach.
HazeFeatureFlags.isPlatformBackdropEnabled = true
```

Requirements and limits:

- Built-in effect support, the **full Android 37.2 gate**, the window and canvas, native setup,
  and the draw must all succeed. It makes rendering *eligible*, not guaranteed.
- It is same-window, previous-pixel ordering. It cannot see later draws, or pixels from another
  dialog, popup, or window.
- It cannot select a specific Haze source.
- On older Android, other platforms, a software canvas, or after a setup/draw failure, the
  modifier uses the configured source fallback. The decision is sticky until detachment and the
  transition may take one frame.
- Changing the flag affects later attachments only.
- `HazeLogger.enabled = true` prints selection and fallback messages; the native draw is marked
  by the `HazeBackdrop.draw` trace section.

Treat it as an experiment to measure, not a default. Ship the source-capture path.

---

## 9. Checklist for a glass layer

- [ ] Effect surfaces are **siblings** of the source, never inside it.
- [ ] `HazeInput.Backdrop` is used unless precise source selection is required.
- [ ] Every glass surface has an opaque, legible fallback.
- [ ] Text on glass meets 4.5:1 (3:1 for large text) in light **and** dark.
- [ ] The user's reduce-transparency preference is honoured (app setting or opaque fallback).
- [ ] ≤ 3 glass surfaces on the busiest screen.
- [ ] `HazePerformanceMode.Default` unless measured otherwise.
- [ ] Frame timing measured on a mid-range device, release build.
- [ ] Large font scale (2.0) reviewed — chrome must not clip.
- [ ] TalkBack announces the same semantics as the non-glass version.
- [ ] Nothing that the user must read for more than ~2 seconds is blurred.
