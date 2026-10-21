# Performance

Glass is the most expensive thing you can add to an Android UI. This file is the budget.

---

## 1. The cost model

A blur/glass surface costs, per frame:

```
cost ≈ (surface area in px) × (blur passes) × (shader complexity) + source-capture cost
```

| Factor | Cheap | Expensive |
|--------|-------|----------|
| Surface area | 1 bar (~360×64 dp) | Full-screen sheet |
| Input mode | `HazeInput.Backdrop` | `HazeInput.Sources` (extra layer capture) |
| Effect | `hazeBlur` | `hazeGlass` (refraction + specular + edge + dispersion) |
| Quality | `Performance` / `Default` | `Quality` (full-resolution input) |
| Extra | Single surface | N surfaces (each is its own render layer) |
| Motion | Static surface | Surface animating (re-draw every frame) |

The killers in practice:

1. **A full-screen glass sheet over a scrolling list.** The source must be captured at full
   size *and* the surface re-composited every frame.
2. **Glass on a scrolling list's items** — the list scrolls, the surface must re-render.
3. **`HazePerformanceMode.Quality` on a large surface.**
4. **Progressive (multi-pass) blur at Quality** — a linear gradient is drawn several times.
5. **Many independent glass surfaces** instead of one merged container.

---

## 2. Budget

| Metric | Target | Hard limit |
|--------|--------|-----------|
| Glass surfaces per screen | ≤ 3 | 5 |
| Total blurred area per screen | ≤ 35 % of the viewport | 60 % |
| Blur radius | ≤ 24 dp for chrome | 40 dp |
| Frame time (scroll) | ≤ 16.6 ms @ 60 Hz, ≤ 8.3 ms @ 120 Hz | drop ≥ 1 frame per 100 |
| Overdraw | ≤ 1.5× | 2× |
| Cold start delta from glass | ≤ 100 ms | 250 ms |

When in doubt, blur less. A 12 dp blur reads as "frosted" nearly as well as 40 dp and costs a
fraction.

---

## 3. Choosing a performance mode

```kotlin
Modifier.hazeBlur(
    input = HazeInput.Backdrop(hazeState),
    style = style,
    performanceMode = HazePerformanceMode.Default,   // == Fixed(0.5f) "Balanced"
)
```

| Mode | Value | Use |
|------|-------|-----|
| `HazePerformanceMode.Performance` | `Fixed(0f)` | Low-end devices, huge surfaces, animation-heavy |
| `HazePerformanceMode.Default` / `Balanced` | `Fixed(0.5f)` | **Default everywhere** |
| `HazePerformanceMode.Quality` | `Fixed(1f)` | Small hero surfaces, screenshots, TV |
| `HazePerformanceMode.Fixed(x)` | 0f..1f | Device-tier tuning |
| `HazePerformanceMode.Adaptive` | *deprecated* | Use `Default` |

Set a process-wide default once:

```kotlin
CompositionLocalProvider(LocalHazePerformanceMode provides HazePerformanceMode.Default) {
    App()
}
```

**Downgrade on low-end devices.** A pragmatic tiering:

```kotlin
val performanceMode = remember {
    if (ActivityManager.isLowRamDevice) HazePerformanceMode.Performance
    else HazePerformanceMode.Default
}
```

Better: gate the whole glass layer off on low-RAM devices and fall back to opaque surfaces.

---

## 4. Measuring

### Frame timing

```bash
# Release build, on the device, warm up first
adb shell dumpsys gfxinfo <pkg> framestats > frames.txt
```

Or use `Macrobenchmark`:

```kotlin
@RunWith(AndroidJUnit4::class)
@LargeTest
class ScrollPerformanceTest {
    @get:Rule val benchmarkRule = MacrobenchmarkRule()

    @Test fun scrollHomeList() = benchmarkRule.measureRepeated(
        packageName = TARGET_PACKAGE,
        metrics = listOf(FrameTimingMetric()),
        iterations = 10,
        setupBlock = { pressHome(); startActivityAndWait() },
    ) { startActivityAndWait(); device.waitForIdle() }
}
```

Targets: `frameDurationCpuMs` p95 < 16.6 ms on a 60 Hz mid-range device; `frameOverrunMs`
count ≈ 0.

### Haze's own tracing

```kotlin
HazeLogger.enabled = true   // dev builds only
```

Haze emits trace sections (`HazeBackdrop.draw`, glass stages) for Perfetto. Capture:

```bash
adb shell perfetto -o /data/misc/perfetto-traces/trace -t 10s sched freq idle am wm gfx view binder_driver hal input res
```

Look for: source-capture passes per frame, shader compile stalls on first use, and frames
where the glass surface is re-rendered while idle.

### The measurement rule

**Do not claim a speedup without a measurement.** Before and after the glass layer, on the
same device, with the same build type, compare:

- scroll frame time (p50/p95) on the busiest list
- cold start (am start -W)
- memory (dumpsys meminfo) — glass render layers cost GPU memory proportional to area
- jank rate in `gfxinfo`

Report the numbers in the upgrade report, with the device named.

---

## 5. Composition-level optimisations

### Merge nearby surfaces

```kotlin
Row(modifier = Modifier.hazeGlassContainer(spacing = 8.dp)) {
    GlassChip(…)   // each is a hazeGlass member
    GlassChip(…)
}
```

One render layer instead of N, and they visually read as one object.

### Source only what you need

```kotlin
// The bar only needs the top 120 dp of content
LazyColumn(modifier = Modifier.hazeSource(hazeState)) { … }
```

Capturing the full 2000-item list as a source is wasteful — Haze captures the source's
rendered layer, and a huge layer is a big texture.

### Keep the effect off the hot path

Don't put glass on a list item that re-binds on every scroll tick. Effects re-run when
their source changes; a source that changes every frame means a glass surface that re-renders
every frame.

### Avoid `expandLayerBounds` on large surfaces

`expandLayerBounds = true` (the default) lets Glass expand its capture layer for optical
sampling. On a large surface, that grows the texture. Try `false` if you see edge banding
or memory pressure.

### Prefer Blur over Glass for large surfaces

`hazeBlur` is a single pass. `hazeGlass` adds refraction, specular, edge, and dispersion
stages. Use Glass for small, prominent controls; use Blur for big chrome.

---

## 6. Startup cost

The first glass frame compiles shaders. Mitigate:

- Warm the effect during a splash/loading screen so the first real frame doesn't stall.
- Avoid creating a `GlassStyle` with per-frame allocations (hoist and `remember` it).
- Don't animate a glass surface in from off-screen on first composition — let it appear.

---

## 7. Memory

| Item | Cost |
|------|------|
| Glass/blur render layer | ≈ width × height × 4 bytes × layers |
| 1 full-screen (1080×2400) RGBA layer | ≈ 10 MB |
| Source capture layer | another ≈ 10 MB if the source is full-screen |

Budget: keep total glass+source layers under ~40 MB on a 4 GB device. If a full-screen
source is captured, ask whether the effect really needs the whole thing.

---

## 8. Common jank causes and fixes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Scroll stutters over a glass bar | Source is the whole list; effect re-renders each frame | Source only visible content; use `Default` mode; reduce radius |
| First frame freezes | Shader compilation | Warm up; avoid animating in |
| Banding on large glass | `expandLayerBounds` + low quality | `expandLayerBounds = false` or higher quality |
| Everything is blurry/soft | Blur radius too large for the surface | ≤ 24 dp for chrome |
| Glass over glass looks wrong | Nested effects | Never nest; use one layer |
| Sheet animation stutters | Animating a full-screen glass sheet | Use an opaque sheet body + glass header |
| Memory grows while scrolling | Source layer re-allocated per scroll | Cap the source; use `Backdrop` |

---

## 9. Performance gates before shipping

- [ ] Scroll frame time p95 < 16.6 ms on a mid-range device, release build
- [ ] No jank frames attributable to the glass layer (`gfxinfo` framestats)
- [ ] Cold start delta from the glass layer < 100 ms
- [ ] Memory delta < 40 MB with the glass layer active
- [ ] ≤ 3 glass surfaces on the busiest screen
- [ ] Blur radius ≤ 24 dp on chrome
- [ ] `HazePerformanceMode.Default` unless a measurement justifies otherwise
- [ ] Low-RAM devices degrade to opaque surfaces, not to a janky app
- [ ] Numbers recorded in the upgrade report, with the device named
