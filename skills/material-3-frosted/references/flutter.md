# Flutter

The Flutter path is not a translation of the Compose path. It has different primitives, one
capability Compose lacks, and one gap that forces a product decision.

Everything below was read from the Flutter 3.47.7 SDK sources and exercised by
`verify/flutter/` — the examples are analysed with `--fatal-infos` and pumped in widget tests.
Where a claim could not be verified it says so instead of guessing.

---

## 1. What Flutter actually gives you

Flutter has no Haze and no `material3` artifact. What it has:

| Need | Flutter primitive | Where |
|---|---|---|
| Backdrop blur | `BackdropFilter(filter:)` or `BackdropFilter(filterConfig:)` | `widgets/basic.dart` |
| Layout-aware blur | `ImageFilterConfig.blur(bounded: true)` | `rendering/image_filter_config.dart` |
| Merge several filters into one pass | `BackdropFilter.grouped` + `BackdropGroup` / `BackdropKey` | `widgets/basic.dart` |
| Disable the effect without changing the tree | `BackdropFilter(enabled: false)` | same |
| Filter the widget's *own* content | `ImageFiltered(imageFilter:)` | `widgets/image_filter.dart` |
| Real spring motion | `SpringSimulation` + `SpringDescription` | `physics/spring_simulation.dart` |

That third row is the important one. **Flutter has the clustering API that Haze 2.0.1 does not**:
grouped backdrop filters share one backdrop input, and the engine merges them into a single
rendering operation. The Android path in this skill has to tell you to keep the glass count low;
the Flutter path can tell you to group them.

`ImageFiltered` is the other half of a distinction people get wrong. `ImageFiltered` blurs the
widget's own child — it is what `Modifier.blur()` is on Compose. `BackdropFilter` blurs what is
*behind* it. A frosted card built with `ImageFiltered` is a blurry card, not frosted glass.

---

## 2. The four rules of the primitive

All four come from the SDK's own documentation and from `BackdropFilter`'s implementation.
Skipping any one of them produces a specific, recognisable bug.

### Rule 1 — Always clip, or you frost the whole screen

> The filter will be applied to all the area within its parent or ancestor widget's clip. If
> there's no clip, the filter will be applied to the full screen.

A `Column` does not clip. A `SafeArea` does not clip. If your 56 dp app bar frosts the entire
viewport, this is why — and the fix is one wrapper:

```dart
ClipRRect(
  borderRadius: shape,
  clipBehavior: Clip.antiAlias,
  child: BackdropFilter(... child: content),
)
```

### Rule 2 — Use the bounded blur, not `filter: ImageFilter.blur(...)`

`ImageFilterConfig.blur` takes the layout into account:

> `bounded` (defaults to false) controls the sampling strategy: if false, the filter is applied to
> the entire canvas using standard sampling. If true, the filter performs a "bounded blur",
> typically used to replicate the high-fidelity frosted-glass effect seen on iOS. In "bounded
> blur" mode, the kernel samples exclusively from within the bounding rectangle of the object.
> Pixels outside the bounds are treated as transparent... This mode prevents color bleeding from
> adjacent content.

```dart
BackdropFilter.grouped(
  filterConfig: ImageFilterConfig.blur(sigmaX: 24, sigmaY: 24, bounded: true),
  child: tint,
)
```

Two consequences worth knowing:

- The bounded path resolves during painting, so it follows the layout. You are not passing a
  `Rect` you have to keep in sync.
- It restricts the *sampling source* but **does not clip the output**. Rule 1 still applies.

The classic `filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24)` still works and is fine for a
cheap approximation. It samples the whole canvas, so bright or saturated content next to the pane
bleeds into its edges. That bleed is the difference between "frosted" and "smudged".

### Rule 3 — Group the filters you cannot merge

```dart
BackdropGroup(                 // one BackdropKey for everything below
  child: Stack(children: [content, appBarGlass, navBarGlass]),
)
```

Each `GlassSurface` uses `BackdropFilter.grouped`, looks up the nearest `BackdropGroup` and takes
its `BackdropKey`. The engine then filters once for the shared backdrop instead of once per
surface.

Two constraints, both from the SDK:

- **Filters that overlap must not share a key.** If two panes overlap and share a key, the
  overlap behaves as if only one filter were applied. Overlapping surfaces get their own
  `BackdropGroup`.
- A grouped filter with no ancestor `BackdropGroup` gets a `null` key — it still works, it just
  does not share anything. `verify/flutter/test/glass_smoke_test.dart` asserts both sides of
  this: same key when grouped, `null` when not, so the test cannot pass vacuously.

### Rule 4 — `enabled: false`, not a no-op filter

> Prefer setting enabled to `false` instead of creating a "no-op" filter type for performance
> reasons.

This is also the fallback story. Keep the filter in the tree with `enabled: scope.blurEnabled`;
the engine skips the work, the tree does not change, and toggling cannot cause a layout jump.

The tint still has to carry the design. Compute the fallback fill so it matches the frosted one's
hue:

```dart
final Color fill = blurEnabled
    ? style.tint
    : Color.alphaBlend(style.tint, scheme.surfaceContainer);
```

`BlendMode.srcOver` is the only `blendMode` supported on every platform. Reach for
`BlendMode.src` only when an ancestor `Opacity` forces a save layer.

---

## 3. Topology: chrome over content, painted in order

A backdrop filter can only filter what has already been painted. In Flutter that is a paint-order
fact you control directly:

```
Stack
├── scrollable content        painted first — this is what the glass samples
├── app bar (glass)           painted over it
└── navigation bar (glass)    Scaffold's bottomNavigationBar, body extended behind
```

Use `Scaffold(extendBody: true, bottomNavigationBar: glassBar)` for the navigation bar — the
Scaffold slot handles safe-area insets and the body genuinely runs beneath it. Keep the app bar in
the `Stack` so the content is guaranteed to be painted first; a `BackdropFilter` in
`Scaffold.appBar` may sample an empty region depending on the body's layout, and that failure is
silent.

The app bar is transparent until content scrolls under it. A bar that is frosted at rest looks
like a mistake; the glass is a *scroll affordance*, not decoration.

Match `Scaffold.appBarTheme` / `NavigationBarThemeData` / `BottomSheetThemeData` background
colours to `Colors.transparent`. Material paints an opaque `Material` first, and your filter then
blurs that flat colour — the bar looks like a slightly greyer solid and nothing warns you.

---

## 4. The accessibility gap: Flutter cannot see "reduce transparency"

This is the one place where Flutter forces a product decision.

`dart:ui`'s `AccessibilityFeatures` (verified in `bin/cache/pkg/sky_engine/lib/ui/window.dart`)
exposes:

```
accessibleNavigation, invertColors, disableAnimations, boldText,
reduceMotion, highContrast, onOffSwitchLabels, supportsAnnounce, ...
```

There is **no** transparency or blur flag. Android has a system blur/transparency preference, iOS
has Reduce Transparency — neither reaches Dart. So:

- **You own the setting.** Ship a switch, persist it (`SharedPreferences`), default it to on.
- Honour `MediaQuery.disableAnimationsOf(context)` for the *transitions* — that one Flutter does
  expose — and use `MediaQuery.highContrastOf(context)` to raise the tint's alpha when the OS
  asks for more contrast.
- The non-blurred state must be designed, not tolerated. See §2 Rule 4.

`disableAnimationsOf`, `highContrastOf`, `textScalerOf`, `accessibleNavigationOf` are all
available on `MediaQuery`.

---

## 5. "Material 3 Expressive" in Flutter: what exists

Flutter's Material 3 is not the Compose `material3` artifact, and the expressive layer landed
there, not here. Verified against `flutter/lib/src/material`:

| Thing | In Flutter 3.47 |
|---|---|
| `useMaterial3` | Yes — **defaults to `true`** |
| `MaterialExpressiveTheme` | ✗ Does not exist |
| `MotionScheme` | ✗ Does not exist |
| `Shapes.largeIncreased` / `extraLargeIncreased` | ✗ Do not exist |
| `NavigationBar`, `NavigationRail`, `NavigationDrawer` | ✓ |
| `SegmentedButton`, `CarouselView`, `SearchBar`, `MenuAnchor` | ✓ |
| `ToggleButtons` (the pre-M3 switch group) | ✓ |
| `FloatingToolbar`, `ButtonGroup`, `SplitButton`, `LoadingIndicator`, `WavyProgressIndicator`, `NavigationSuiteScaffold` | ✗ Absent |

So "expressive in Flutter" means doing by hand what Compose gives you as tokens:

- **Type** — an emphasized `titleLarge`: 22sp / 28sp line height / `w600`. Highest value, lowest
  risk, one line in `ThemeData`.
- **Shape** — `StadiumBorder()` on buttons, `RoundedRectangleBorder` at 16/28 on containers, and
  the increased radii (20/32) for hero moments. There are no named tokens to reference, so put
  the numbers in one place (`GlassStyle` in `glass_theme.dart` is that place).
- **Motion** — no motion scheme, but real springs are available:

  ```dart
  AnimationController(vsync: this).animateWith(
    SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 30),
      0, 1, 0,   // start, end, velocity
    ),
  )
  ```

  `SpringDescription` and `SpringSimulation` are in `package:flutter/physics.dart`. Prefer them
  over `Curves.easeInOut` + `Duration(milliseconds: 300)` for anything that responds to a finger.
- **Components** — you get the M3 set, not the expressive set. `SegmentedButton` and `CarouselView`
  are the two that read as "new" to users.

Do not port Compose expressive code into Flutter expecting it to compile. `MaterialExpressiveTheme`
does not exist here; see the breakage table in §8.

---

## 6. Platform behaviour

The blur is an engine feature, so it behaves consistently across Flutter's mobile and desktop
targets. The web has one fact that invalidates most older advice:

**The HTML renderer no longer exists.** Verified in `flutter_tools/lib/src/web/compile.dart`:
`enum WebRendererMode` has exactly two values, `canvaskit` (default for JS) and `skwasm` (default
for WASM). The "HTML renderer cannot blur" caveat you will find in older blog posts is obsolete —
both current options render `BackdropFilter`.

| Target | Glass | Notes |
|---|---|---|
| Android | ✓ | Cost scales with filtered area; low-end GPUs feel it |
| iOS | ✓ | `bounded: true` is the mode that matches the native look |
| Web (canvaskit / skwasm) | ✓ | Cost is worse than native; budget 1–2 surfaces |
| macOS / Windows / Linux | ✓ | Desktop windows are large — full-width bars filter a big area |

What is *not* portable: the system's own reduce-transparency preference (see §4), and the exact
appearance of the platform's native material. Expect a Flutter frosted bar to look close to, not
identical with, the OS chrome.

---

## 7. Performance

The cost model is simple and it is about **area**, not count:

- A backdrop filter forces the engine to capture and filter an offscreen region behind the widget.
  A full-width bar costs the bar's width × height; a full-screen scrim costs the whole screen.
- Grouping reduces how many times that capture is performed for a shared backdrop — it does not
  reduce the area.
- Merging several surfaces into one pane reduces both. This is why the segmented control example
  is one pane containing a control, not one pane per segment.

Practical rules:

1. **Cap glass surfaces per screen at 2–3.** Same budget as the Android path.
2. **Never let a glass surface grow to full-screen.** A sheet body, a dialog background, a scroll
   view — all Tier 3.
3. **Don't wrap the filtered widget in `Opacity`.** It forces a save layer and changes how the
   backdrop composites; use the tint's alpha instead.
4. **`RepaintBoundary` around the *content*, not around the glass.** The point is to stop content
   scrolling from re-filtering, not to isolate the filter.
5. **Measure on a mid-range device in release mode.** `flutter run --profile` plus the DevTools
   frame chart; a debug build tells you nothing about raster cost. Look for raster time, not
   UI-thread time: backdrop filters show up in `Raster`.

---

## 8. Anti-patterns and their symptoms

| Symptom | Cause | Fix |
|---|---|---|
| Whole screen is frosted | No clip above the filter | `ClipRRect` / `ClipRect` (Rule 1) |
| Edges of the pane look muddy, colour bleeds in | `filter: ImageFilter.blur`, unbounded sampling | `ImageFilterConfig.blur(bounded: true)` (Rule 2) |
| Bar looks like a flat grey solid | An opaque `Material` / `backgroundColor` above the filter | Transparent app-bar, nav-bar and sheet theme colours |
| Glass shows nothing at all | The filter is painted before the content, or sits in its own source | Put the glass after the content in a `Stack` |
| Overlapping panes look like one filter | Two grouped filters share a `BackdropKey` | Give the overlapping surfaces their own `BackdropGroup` |
| Text unreadable with blur off | The tint was never designed to stand alone | Raise the fallback alpha; verify contrast in both states |
| `MaterialExpressiveTheme` not found | It does not exist in Flutter | §5 — hand-build type, shape and springs |
| Jank on scroll | Large filtered area, or N ungrouped filters | Shrink the area, group, then merge panes |

---

## 9. Checklist

- [ ] Every `BackdropFilter` has a clipping ancestor.
- [ ] Every blur uses `bounded: true` (or you knowingly chose the cheap path).
- [ ] Chrome uses `BackdropFilter.grouped` under one `BackdropGroup` per screen region.
- [ ] Overlapping glass surfaces are in separate groups.
- [ ] `enabled` is driven by an app-level switch, and the non-blurred state is designed.
- [ ] Theme colours for app bar, navigation bar and sheet are transparent.
- [ ] `titleLarge` is emphasized; at least one spring-based transition exists.
- [ ] Glass count per screen ≤ 3, none full-screen.
- [ ] `flutter analyze --fatal-infos` is clean and the widget tests pass.
