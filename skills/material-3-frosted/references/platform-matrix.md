# Platform matrix

What works where, and which versions to pin. Verified against the AndroidX and Haze
repositories.

---

## 1. Platform releases

| Release | API | Codename | Notes |
|---------|-----|----------|-------|
| Android 15 | 35 | Vanilla Ice Cream | Edge-to-edge enforced on Android 15+ targetSdk 35 |
| Android 16 | 36 | Baklava | Live text, HDR image decoding, `WindowManager.isCrossWindowBlurEnabled` reaches devices |
| Android 16 QPR2 | 36.1 | — | *Reduce blur effects* accessibility toggle surfaces to apps |
| **Android 17** | **37** | **Cinnamon Bun** | Native window backdrop path (37.2+), further expressive polish, `compileSdk`/`targetSdk` 37 |

**Target `compileSdk 37` / `targetSdk 37`** for an Android 17-era upgrade, but only after
checking the app's behaviour under Android 15+ edge-to-edge enforcement and the Android 16
predictive-back behaviour. Raising `targetSdk` without testing is a behaviour change, not a
UI change.

**`minSdk`**: raise only with a reason. Android 15+ already covers the overwhelming majority
of active devices. Do not raise `minSdk` during a UI upgrade — it is a separate decision with
its own testing burden.

---

## 2. Version pins (verified)

### Compose

| Artifact | Version | Notes |
|----------|---------|-------|
| `androidx.compose:compose-bom` | `2026.09.00` | Latest BOM; pins material3 **1.4.0** |
| `androidx.compose.material3:material3` | `1.5.0-beta01` | **Override** — 1.4.0's expressive APIs are `internal` |
| `androidx.compose.material3:material3-adaptive-navigation-suite` | `1.5.0-beta01` | `NavigationSuiteScaffold` (BOM pins 1.4.0) |
| `androidx.compose.material3:material3-window-size-class` | `1.4.0` | Leave to the BOM — no expressive API here |
| `androidx.compose.material3:material3-adaptive` | `1.4.0` | `currentWindowAdaptiveInfo()` |
| `androidx.activity:activity-compose` | `1.13.0` | `enableEdgeToEdge()` |
| `androidx.lifecycle:lifecycle-runtime-compose` | `2.11.0` | `collectAsStateWithLifecycle()` |
| `androidx.core:core-ktx` | `1.19.1` | |

```kotlin
dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)

    // Explicit override: the BOM's 1.4.0 hides the Expressive APIs behind `internal`.
    implementation("androidx.compose.material3:material3:1.5.0-beta01")
    implementation("androidx.compose.material3:material3-adaptive-navigation-suite:1.5.0-beta01")

    implementation("androidx.compose.material3:material3-window-size-class")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
}
```

**Verify the resolved version before believing it:**

```bash
./gradlew :app:dependencies --configuration debugRuntimeClasspath | grep material3
```

### Views (Material Components)

| Artifact | Version | Notes |
|----------|---------|-------|
| `com.google.android.material:material` | `1.14.0` | Stable Material 3 for Views |
| `androidx.window:window` | `1.5.1` | `WindowInfoTracker` for foldables, `WindowMetricsCalculator` |
| `androidx.appcompat:appcompat` | `1.7.x` | |

### Frosted layer (Haze 2)

All Haze artifacts are released in lockstep — **use the same version for all of them**.

| Artifact | Version | Provides |
|----------|---------|----------|
| `dev.chrisbanes.haze:haze` | `2.0.1` | Core: `HazeState`, `HazeInput`, `hazeSource`, `HazePerformanceMode` |
| `dev.chrisbanes.haze:haze-blur` | `2.0.1` | `hazeBlur`, `HazeBlurStyle` |
| `dev.chrisbanes.haze:haze-blur-materials` | `2.0.1` | `HazeMaterials`, `CupertinoMaterials`, `FluentMaterials` |
| `dev.chrisbanes.haze:haze-blur-material3` | `2.0.1` | `HazeBlurStyle.Material3` |
| `dev.chrisbanes.haze:haze-glass` | `2.0.1` | `hazeGlass`, `GlassStyle`, `GlassOptics` |
| `dev.chrisbanes.haze:haze-glass-material3` | `2.0.1` | `GlassStyle.material3` |

Haze 2.0.1 is the current stable. `2.0.0-alpha*`/`beta*`/`rc*` are not production-ready
releases.

---

## 3. Feature → platform support

| Feature | Compose | Views | min API | Notes |
|---------|---------|-------|---------|-------|
| `MaterialExpressiveTheme` | ✅ (1.5.0-beta01+) | ❌ | 21 | `internal` in 1.4.0; Compose-only |
| `MotionScheme` (spring tokens) | ✅ (1.5.0-beta01+) | ❌ | 21 | `expressive()` is `internal` in 1.4.0 |
| `ButtonGroup`, `SplitButton` | ✅ (1.5.0-beta01+) | ⚠️ partial | 21 | Views: `MaterialButtonToggleGroup` only |
| `LoadingIndicator` (expressive) | ✅ (1.5.0-beta01+) | ❌ | 21 | Compose-only |
| `Carousel` (unbounded) | ✅ (1.4.0+) | ⚠️ | 21 | |
| `SearchBar` (expressive) | ✅ (1.4.0+) | ❌ | 21 | |
| `ToggleButton` | ✅ (1.5.0-beta01+) | ❌ | 21 | |
| `SegmentedButton`, `ShortNavigationBar`, `WideNavigationRail` | ✅ (1.4.0+) | ⚠️ | 21 | Views: `NavigationRailView` / `MaterialButtonToggleGroup` |
| `Shapes.largeIncreased` / `extraLargeIncreased` | ✅ (1.5.0-beta01+) | ⚠️ | 21 | `internal` in 1.4.0; Views: custom `shapeAppearanceOverlay` |
| `NavigationSuiteScaffold` | ✅ | ❌ | 21 | Compose-only; Views: `NavigationRailView` + manual breakpoint logic |
| `currentWindowAdaptiveInfo()` | ✅ | ❌ | 21 | Views: `WindowInfoTracker` + `WindowMetricsCalculator` |
| `ListDetailPaneScaffold` | ✅ | ❌ | 21 | |
| `enableEdgeToEdge()` | ✅ | ✅ | 21 | Views: `WindowCompat.setDecorFitsSystemWindows(window, false)` |
| Dynamic colour | ✅ | ✅ | 31 | `dynamicLightColorScheme` / `DynamicColors.applyToActivitiesIfAvailable` |
| `Modifier.blur()` | ✅ | ⚠️ | 31 | Blurs own content only |
| `Modifier.graphicsLayer(renderEffect = BlurEffect)` | ✅ | ⚠️ | 31 | |
| `Window.setBackgroundBlurRadius()` | ✅ | ✅ | 31 | Cross-window |
| `FLAG_BLUR_BEHIND` / `blurBehindRadius` | ✅ | ✅ | 31 | Cross-window |
| `WindowManager.isCrossWindowBlurEnabled()` | ✅ | ✅ | 31 | Read at runtime; flips with settings |
| `addCrossWindowBlurEnabledListener` | ✅ | ✅ | 31 | |
| `RenderNode` backdrop capture (Haze native path) | ✅ | ❌ | 31 (Haze 2 requires API 31+ on Android) | Haze 2 requires **API 31+** for the blur/glass runtime |
| Android native window backdrop (Haze `isPlatformBackdropEnabled`) | ✅ | ❌ | 37.2 | Experimental; Android 17.2+ only |
| AGSL / `RuntimeShader` (Glass) | ✅ | ❌ | 33 | Glass refraction needs API 33+; Haze degrades below that |
| `Modifier.hazeGlass` | ✅ | ❌ | 33 | Glass requires AGSL (API 33+) |
| Predictive back | ✅ | ✅ | 33 | `PredictiveBackHandler` |
| `LocaleList` / per-app language | ✅ | ✅ | 33 | |
| `enableEdgeToEdge` predictive insets | ✅ | ✅ | 35 | `WindowInsets` animation APIs |
| `Modifier.blur` on API 31–32 | ✅ | ⚠️ | 31 | Hardware-dependent |
| Material 3 Expressive in Views | ❌ | ⚠️ | 21 | Material Components 1.14.0 has some expressive components; no `MotionScheme` equivalent |
| `MaterialTheme` / dynamic colour (Flutter) | ✅ | — | 21 | Use `useMaterial3: true` + `ColorScheme.fromSeed` |
| Glass in Flutter | ⚠️ | — | 21 | `BackdropFilter` / `ImageFilter.blur`; no native Haze equivalent |

### The Views/Compose gap, stated plainly

Material 3 Expressive is a **Compose-first** design system. In Views you get expressive
*components* (Material Components 1.14.0), but not `MotionScheme`, not `MaterialExpressiveTheme`,
not the expressive shape tokens as first-class roles, and not the glass layer.

If the target app is Views-based, the realistic plan is:

1. MD3 tokens + components + dynamic colour (real, complete win).
2. Expressive components where they exist.
3. Platform window blur for dialogs/popups (real, but window-level, not composable-level).
4. Skip the composable glass layer, or plan a Compose island for the highest-value screen.

Do not pretend a Views app can be brought to full Expressive parity in the same pass.

---

## 4. Haze platform requirements

| Requirement | Detail |
|--------------|--------|
| **minSdk 31** | Haze 2 requires API 31+ on Android. Below that, the blur/glass runtime is unavailable. |
| **AGSL shaders** | `haze-glass` needs API 33+ (`RuntimeShader`). Below that, use `haze-blur` (RenderEffect-based). |
| **Native backdrop (opt-in)** | Android 37.2+ only, experimental, off by default. |
| **Other platforms** | Haze supports iOS/desktop/web too, but this skill is Android-only. |

If the app's `minSdk` is below 31, you have three options:

1. Raise `minSdk` to 31 (a real product decision — get sign-off).
2. Ship Blur-only, and skip Glass (RenderEffect blur also needs API 31 — so this does not
   help below 31).
3. Ship no glass, or a pre-rendered/static "frosted" texture approximation for very old
   devices.

Reality: below API 31 there is no real system blur. Do not fake it with a semi-transparent
white rectangle and call it glass.

---

## 5. Decision table: mechanism by API level

| API | Recommended glass mechanism |
|-----|----------------------------|
| 37.2+ | Haze Glass (optionally with the experimental native backdrop, measured) |
| 33–36 | Haze Glass; Haze Blur for large surfaces |
| 31–32 | Haze Blur only (no AGSL → no refraction); platform window blur for dialogs |
| < 31 | No blur. Opaque M3 surfaces with tonal elevation. |

---

## 6. Device classes

| Class | Width (dp) | Navigation | Layout |
|-------|-----------|------------|--------|
| Compact | < 600 | Bottom bar | Single pane |
| Medium | 600–839 | Navigation rail | Single or two-pane (list-detail) |
| Expanded | ≥ 840 | Navigation drawer (or rail) | Two/three-pane, `ListDetailPaneScaffold` |
| Foldable, closed | Compact | Bottom bar | Single pane |
| Foldable, open | Medium/Expanded | Rail | Two-pane, hinge-aware |

Foldables: respect the hinge. `androidx.window` gives you `FoldingFeature` with a hinge
bounds; never place a control or a list item under the hinge.

---

## 7. Upgrading a dependency set

Order matters — bump lowest-risk first so a failure localises.

```kotlin
// 1. Compose BOM alone (no code change expected)
implementation(platform("androidx.compose:compose-bom:2026.09.00"))
// → run: ./gradlew :app:assembleDebug :app:lint

// 2. Material Components (Views only)
// → check for renamed attrs: useMaterial3, colorSurfaceVariant deprecations

// 3. activity-compose (enableEdgeToEdge)
// → verify insets handling in every screen

// 4. Haze artifacts (all at the same version)
// → verify glass surfaces still resolve; the API changed between 1.x and 2.x
```

Haze 1.x → 2.x is a breaking change: package layout, `HazeInput` and the effect modifiers
were reworked. Read the Haze 2 migration notes before porting.

---

## 8. Sources

- Compose Material3 release notes —
  https://developer.android.com/jetpack/androidx/releases/compose-material3
- Compose BOM — https://developer.android.com/jetpack/androidx/compose/compose-bom
- Material Components (Views) — https://developer.android.com/jetpack/androidx/releases/material
- AOSP window blurs — https://source.android.com/docs/core/display/window-blurs
- Haze — https://github.com/chrisbanes/haze
- Material 3 Expressive — https://m3.material.io/blog/whats-new-at-io26
- Android 17 — https://developer.android.com/about/versions/17
