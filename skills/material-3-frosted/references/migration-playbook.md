# Migration playbook

Ordered recipes for taking an existing app to the target stack. Work top to bottom; each step
is independently shippable.

---

## 1. Dependencies & SDK

```kotlin
// gradle/libs.versions.toml
[versions]
composeBom = "2026.09.00"
// The BOM pins material3 1.4.0, where MaterialExpressiveTheme, MotionScheme.expressive()
// and the increased shapes are `internal`. 1.5.0-beta01 makes them public.
material3 = "1.5.0-beta01"
activityCompose = "1.13.0"
haze = "2.0.1"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
compose-material3 = { group = "androidx.compose.material3", name = "material3", version.ref = "material3" }
compose-material3-adaptive-nav = { group = "androidx.compose.material3", name = "material3-adaptive-navigation-suite", version.ref = "material3" }
compose-material3-window-size = { group = "androidx.compose.material3", name = "material3-window-size-class", version.ref = "material3" }
activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
haze = { group = "dev.chrisbanes.haze", name = "haze", version.ref = "haze" }
haze-blur = { group = "dev.chrisbanes.haze", name = "haze-blur", version.ref = "haze" }
haze-blur-materials = { group = "dev.chrisbanes.haze", name = "haze-blur-materials", version.ref = "haze" }
haze-glass = { group = "dev.chrisbanes.haze", name = "haze-glass", version.ref = "haze" }
haze-glass-material3 = { group = "dev.chrisbanes.haze", name = "haze-glass-material3", version.ref = "haze" }
```

```kotlin
// app/build.gradle.kts
android {
    compileSdk = 37
    defaultConfig {
        targetSdk = 37
        // minSdk: raise only with a reason and a migration note.
    }
    buildFeatures { compose = true }
}
```

**Order of operations**

1. Bump `compileSdk` + `targetSdk`. Fix the resulting deprecation and behaviour errors **before**
   touching design — otherwise you cannot tell which break came from which change.
2. Move to the Compose BOM. Never pin Compose libraries individually.
3. Upgrade `material3` to **1.5.0-beta01** (explicitly — the BOM's 1.4.0 hides the Expressive
   APIs). Read the release notes for every version you jump over; expressive components were
   renamed repeatedly across the alpha series, so verify each name against the artifact before
   writing it: `./gradlew :app:dependencies` plus the Compose Material3 release notes.
4. Add `haze` modules **last**, after the M3 Expressive layer is correct.

**Target SDK bumps are behaviour changes, not style changes.** Android 17 (API 37) restricts
background work, changes notification behaviour, and enforces edge-to-edge. Review the
behaviour-changes page for your target SDK before shipping.

---

## 2. MD2 → MD3

### Theme

```xml
<!-- Before (MD2) -->
<style name="Theme.App" parent="Theme.MaterialComponents.DayNight">
    <item name="colorPrimary">@color/purple_500</item>
    <item name="android:statusBarColor">@color/purple_700</item>
</style>

<!-- After (MD3) -->
<style name="Theme.App" parent="Theme.Material3.DayNight">
    <item name="colorPrimary">@color/md_theme_light_primary</item>
    <item name="android:statusBarColor">@android:color/transparent</item>
    <item name="android:windowLightStatusBar">true</item>
</style>
```

The fastest correct path for Views apps: replace the parent theme with
`Theme.Material3.DayNight`, then map the old colour attributes to the MD3 roles
(`colorPrimary` → `colorPrimary`, `colorAccent` → `colorSecondary`, `colorControlNormal` →
`colorOnSurfaceVariant`, `android:colorBackground` → `colorSurface`), then re-point each layout
to the MD3 widget classes.

### Component mapping

| MD2 | MD3 | Notes |
|-----|-----|-------|
| `AppBarLayout` | `TopAppBar` / `CenterAlignedTopAppBar` | Not a drop-in — restructure the layout |
| `Toolbar` | `TopAppBar` | |
| `BottomNavigationView` | `NavigationBarView` | |
| `NavigationView` (drawer) | `NavigationDrawerView` | |
| `TabLayout` | `TabLayout` (M3) | Different styling; `TabLayoutMediator` still works |
| `FloatingActionButton` | `FloatingActionButton` | |
| `ExtendedFloatingActionButton` | `ExtendedFloatingActionButton` | |
| `MaterialButton` | `MaterialButton` | `style="@style/Widget.Material3.Button"` |
| `TextInputLayout` (filled) | `TextInputLayout` (filled) | MD3 filled fields use a different box treatment |
| `TextInputEditText` | `TextInputEditText` | |
| `CardView` | `MaterialCardView` | |
| `Chip` | `Chip` | MD3 chip API differs (`chipIcon`, `ensureMinTouchTargetSize`) |
| `FloatingActionButton` + menu | `FloatingActionButton` + `PopupMenu` | Or Expressive `ButtonGroup` |
| `RecyclerView` | `RecyclerView` | Still correct — M3 is about theming, not the view |
| `Snackbar` | `Snackbar` | |
| `AlertDialog` | `MaterialAlertDialogBuilder` | |
| `BottomSheetDialog` | `BottomSheetDialog` | |
| `CircularProgressIndicator` | `CircularProgressIndicator` | Prefer Expressive `LoadingIndicator` in Compose |
| `SwitchMaterial` | `SwitchMaterial` | MD3 has a new switch style |
| `Slider` | `Slider` | MD3 slider is much taller with a new handle |
| `ImageView` + `srcCompat` | `ShapeableImageView` | For rounded/circular media |
| `CoordinatorLayout` | `CoordinatorLayout` | Still fine |

### Do not do this

- Do not keep `Theme.MaterialComponents` and call `colorPrimary` "MD3". The MD2 palette is not
  the MD3 palette.
- Do not mix `com.google.android.material` MD2 widgets with `com.google.android.material3`
  widgets in the same layout — theme attributes collide.
- Do not port only the buttons. MD2's raised button, MD2's filled text field with a hard
  underline, and MD2's monochrome app bar are what make an app look dated. Replace them.

---

## 3. Views → Compose (incremental)

Do not rewrite the app. Migrate screen by screen.

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AppTheme {
                AppNavHost()
            }
        }
    }
}
```

**Step 1 — host Compose in the existing View tree.** Keep the existing `Activity`, replace one
layout with a `ComposeView`:

```xml
<androidx.compose.ui.platform.ComposeView
    android:id="@+id/compose_view"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

```kotlin
findViewById<ComposeView>(R.id.compose_view).setContent {
    AppTheme { HomeScreen() }
}
```

**Step 2 — share state.** Expose the ViewModel to Compose with
`viewModel.composeLocalOf` or pass it in; expose View state to Views through
`AndroidView`/`state` flows. Do not duplicate state in two worlds.

**Step 3 — migrate shared components first.** Buttons, cards, text fields, list rows, the app
bar, the nav bar. They are used everywhere, so the payoff compounds.

**Step 4 — migrate navigation.** Use `NavHost` for the migrated screens; keep the View-based
`FragmentNavigator` for the rest, or bridge via a shared `NavController`.

**Step 5 — delete the old theme.** The moment the last screen leaves Views, remove the MD2
theme and the unused MD2 resources.

**Where to put Compose code:** in the existing package structure (`ui/`, `feature/`,
`component/`), not a parallel `compose/` tree that will drift.

---

## 4. Theming (Compose)

```kotlin
@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialExpressiveTheme(
        colorScheme = colorScheme,
        motionScheme = MotionScheme.expressive(),
        typography = AppTypography,   // your own Typography()
        shapes = AppShapes,           // see FrostedShapes in the example
        content = content,
    )
}
```

Put the glass styles in the same theme file so the app has **one** place where visual
decisions live. See `assets/examples/FrostedTheme.kt`.

---

## 5. Edge-to-edge

```kotlin
// Activity
enableEdgeToEdge()   // androidx.activity:activity-compose
```

```kotlin
// Compose
Scaffold(
    topBar = { TopAppBar(...) },
    bottomBar = { NavigationBar(...) },
) { innerPadding ->
    LazyColumn(
        contentPadding = innerPadding,   // as contentPadding, NOT Modifier.padding
        modifier = Modifier.fillMaxSize(),
    ) { … }
}
```

Rules:

- Pass the scaffold padding as `contentPadding` to the scrolling container so content scrolls
  **under** the bars while staying reachable. `Modifier.padding(innerPadding)` clips the
  scroll range and produces the classic "content stops at the bar" bug.
- Add `imePadding()` to the bottom bar slot when the app has inputs.
- `Modifier.consumeWindowInsets(innerPadding)` is needed when a child also consumes insets.
- Do not use `statusBarsPadding()` scattered across screens; insets belong to the chrome.
- Remove `android:fitsSystemWindows` hacks and manual `window.statusBarColor` assignments.
- For a transparent status bar, `enableEdgeToEdge()` handles the light/dark icon colour.

---

## 6. Predictive back

Android 13+ supports predictive back; Android 16/17 expects it.

```kotlin
// Manifest
<application android:enableOnBackInvokedCallback="true" />
```

In Compose, `NavHost` and the standard `BackHandler` already integrate. Custom transitions
need `PredictiveBackHandler`:

```kotlin
PredictiveBackHandler { /* animate back to the previous state */ }
```

Never intercept back without providing a way back.

---

## 7. Per-component recipes

### Top app bar that becomes translucent on scroll

```kotlin
val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior()
val appBarState by scrollBehavior.state
val isScrolled = appBarState.collapsedFraction > 0.01f

TopAppBar(
    scrollBehavior = scrollBehavior,
    colors = TopAppBarDefaults.topAppBarColors(
        containerColor = if (isScrolled) Color.Transparent else MaterialTheme.colorScheme.surface,
        scrolledContainerColor = Color.Transparent,
    ),
)
```

### Navigation bar that adapts to width

```kotlin
NavigationSuiteScaffold(
    navigationSuiteItems = {
        destinations.forEach { destination ->
            item(
                selected = destination == current,
                onClick = { onNavigate(destination) },
                icon = { Icon(destination.icon, contentDescription = null) },
                label = { Text(destination.label) },
            )
        }
    },
) { content ->
    // content
}
```

### Lists

```kotlin
LazyColumn(contentPadding = innerPadding) {
    items(items, key = { it.id }) { item ->
        ListItem(
            headlineContent = { Text(item.title) },
            supportingContent = { Text(item.subtitle) },
            leadingContent = { Icon(item.icon, contentDescription = null) },
            modifier = Modifier.animateItem(),
        )
    }
}
```

Always supply a `key`. Use `Modifier.animateItem()` for reorder/insert animations.

### Dialogs and sheets

```kotlin
// Dialog — MD3 basic dialog
BasicAlertDialog(onDismissRequest = onDismiss) { AlertDialogContent() }

// Bottom sheet
ModalBottomSheet(onDismissRequest = onDismiss) { SheetContent() }
```

For a **glass** sheet, the sheet body stays an opaque `surfaceContainerLow`; only the handle
area and the header may be glass. See `assets/examples/GlassSheet.kt`.

### Text fields

Use `OutlinedTextField` for forms and `TextField` for dense contexts. Never hard-code the
container colour — let the component pick `surfaceContainerHighest` / `surface`.

### FAB that morphs

```kotlin
val expanded by remember { mutableStateOf(false) }
val corner by animateDpAsState(
    targetValue = if (expanded) 28.dp else 16.dp,
    animationSpec = MaterialTheme.motionScheme.defaultSpatialSpec(),
)
ExtendedFloatingActionButton(
    onClick = { expanded = !expanded },
    expanded = expanded,
    icon = { Icon(Icons.Default.Add, contentDescription = null) },
    text = { Text("Create") },
)
```

---

## 8. Common breakages

| Symptom | Cause | Fix |
|---------|-------|-----|
| Content stops above the bottom bar | `Modifier.padding(innerPadding)` on a scrolling container | Use `contentPadding` |
| Status bar icons invisible in dark mode | Manual `statusBarColor` | `enableEdgeToEdge()` and remove the override |
| Glass shows nothing | The effect is inside its own source | Move the effect out of the source subtree |
| Glass is black | No tint + dark appearance | Tint with `surfaceContainer*`; verify the dark scheme |
| Blur flickers on scroll | Source is the whole screen, or `HazeInput.Sources` with a moving source | Source only the content; use `Backdrop` |
| `MaterialExpressiveTheme` unresolved | `material3` is 1.4.0, where it is `internal` | Override `material3` to 1.5.0-beta01 |
| `MotionScheme.expressive()` unresolved | Same — `internal` in 1.4.0 | Override `material3` to 1.5.0-beta01 |
| `Shapes.largeIncreased` unresolved | `internal` in 1.4.0 | 1.5.0-beta01, or use `large`/`extraLarge` |
| `ButtonGroup` / `SplitButton` unresolved | Not present before 1.5.0-beta01 | 1.5.0-beta01, or use `SegmentedButton` |
| `Unresolved reference: hazeGlassContainer` | Clustering API is on Haze `main`, not in 2.0.1 | Remove it; keep glass groups to 2–3 members |
| `ModalBottomSheetDefaults.DragHandle` unresolved | The handle lives on `BottomSheetDefaults` in current material3 | `BottomSheetDefaults.DragHandle()` |
| Glass never appears although the code looks right | `LocalView.current.context` is a `ContextWrapper`, not the `Activity` | Unwrap to the `Activity` before touching `window` |
| Dialogs unreadable over content | Translucent window with no fallback | Raise the background alpha when blur is off |
| Tab crashes on API 26 | Material3 1.4 requires a higher minSdk for some APIs | Check Material3's minSdk; raise minSdk if justified |

---

## 9. Refactor rules

You are allowed to restructure — that is often what the upgrade requires. Follow these:

1. **One theme source of truth.** Colours, type, shapes, motion, and glass styles live in one
   module (`ui/theme`). No per-screen colour objects.
2. **Shared components are a public API.** If a component is used on 5+ screens, it belongs in
   the shared module, themed by tokens only.
3. **No business logic in composables.** Keep view models/view state out of the UI layer so the
   UI can be rewritten without touching logic.
4. **Semantic naming.** `GlassAppBar`, not `AppBar2`. `AppBar2` is how apps rot.
5. **Delete the old code.** Leaving the MD2 theme "just in case" doubles the maintenance and
   guarantees drift.
6. **One PR per workstream.** A PR that mixes a theme change with a navigation rewrite cannot
   be reviewed.
