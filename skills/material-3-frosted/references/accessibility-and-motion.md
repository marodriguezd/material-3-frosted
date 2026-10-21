# Accessibility & motion

An upgrade that fails accessibility is not an upgrade. Every rule here is a gate, not a
nice-to-have.

---

## 1. The four system switches

Android exposes user preferences that must change the UI, not just be "considered".

| Setting | Where | How to detect |
|---------|-------|---------------|
| **Remove animations** (animation scale = 0) | Accessibility → Visual effects / Developer options → Animator duration scale | `ValueAnimator.areAnimatorsEnabled()` (API 26+) |
| **Reduce blur effects** | Accessibility → Color & motion → *Reduce blur effects* (Android 17 / API 37) | `windowManager.isCrossWindowBlurEnabled` for window blur; for app-drawn blur, honour the same intent via a contrast fallback |
| **Remove animations / reduce motion** | Accessibility → Visual effects | Same `areAnimatorsEnabled()` gate |
| **Dark theme** | Settings → Display | `isSystemInDarkTheme()` / `Configuration.uiMode` |

Android has no public *high-contrast* flag: do not read one. Meet the contrast ratios in §3
instead, and test with the OEM's contrast setting enabled.

**Treat "animation scale = 0" as "no animation", not "fast animation".** A 0 ms duration
spring is still a spring: it can overshoot. Use an instant path.

```kotlin
val animationsEnabled = ValueAnimator.areAnimatorsEnabled()
val spec = if (animationsEnabled) {
    MaterialTheme.motionScheme.defaultSpatialSpec()
} else {
    snap()
}
```

`MaterialTheme.motionScheme` is theme-driven, but you still need the `areAnimatorsEnabled()`
check for the user-level animation scale.

---

## 2. Reduce blur

Windows can be blurred by the system only if blur is enabled. Query it:

```kotlin
val blurEnabled = windowManager.isCrossWindowBlurEnabled()   // API 31+
```

`windowManager.isCrossWindowBlurEnabled()` reflects both the system capability **and** user
settings (including *Reduce blur effects* on Android 17). If it returns false, do not request
`FLAG_BLUR_BEHIND` — the request is ignored anyway — and render the opaque fallback.

For **app-drawn** blur (Haze), the app is drawing pixels, so the system setting does not
automatically stop it. Two options:

1. **Treat "blur disabled" as a contrast requirement.** Android does not expose a public
   accessor for the app-drawn *Reduce blur effects* toggle. Use
   `windowManager.isCrossWindowBlurEnabled()` where window blur is involved, and otherwise
   expose an in-app reduce-transparency preference (or follow the system's dark/high-contrast
   state) and fall back to the opaque container.
2. **Always ship the opaque fallback anyway.** Even if you cannot detect the setting, the
   app must be legible if blur is unavailable (low-end device, battery saver, screenshot,
   screen reader).

```kotlin
// Opaque fallback is the DEFAULT state; glass is the enhancement.
val glassAvailable = remember { windowManager.isCrossWindowBlurEnabled() }
val containerColor = if (glassAvailable) Color.Transparent
                     else MaterialTheme.colorScheme.surfaceContainer
```

**Never** make the glass surface's *only* way of being legible. Every screen must pass
contrast with the blur fully disabled.

---

## 3. Contrast

| Content | Minimum |
|---------|---------|
| Body text (< 18sp regular / < 14sp bold) | 4.5:1 |
| Large text (≥ 18sp regular / ≥ 14sp bold) | 3:1 |
| Icons, graphical objects, component boundaries | 3:1 (WCAG 1.4.11) |
| Text over images/media | 4.5:1 against the *worst* pixel behind it |

**Glass surfaces:** measure the contrast of the text against the *tinted* surface, not
against the raw background. A 12 % white tint over a dark photo may leave white text at
2.8:1. The mitigation is a container colour with enough alpha, or a scrim over media.

```kotlin
// Verify with a real check, not by eye.
fun contrastRatio(fg: Color, bg: Color): Float {
    fun lum(c: Color): Float {
        fun ch(v: Float) = if (v <= 0.03928f) v / 12.92f
                           else ((v + 0.055f) / 1.055f).pow(2.4f)
        return 0.2126f * ch(c.red) + 0.7152f * ch(c.green) + 0.0722f * ch(c.blue)
    }
    val l1 = lum(fg); val l2 = lum(bg)
    val (hi, lo) = if (l1 > l2) l1 to l2 else l2 to l1
    return (hi + 0.05f) / (lo + 0.05f)
}
```

Use this in a screenshot/unit test over a worst-case background (e.g. pure white photo
under a light glass bar) — a real composite, not a flat colour.

**Do not use colour alone** to convey state: errors, selected/unselected, enabled/disabled.
Pair with an icon, a shape change, or text.

---

## 4. Touch targets

- Minimum **48dp × 48dp** for every interactive element.
- `Modifier.minimumInteractiveComponentSize()` (Compose) or
  `android:minWidth` / `android:minHeight` plus a `TouchDelegate` (Views).
- Icon buttons: give the *button* the 48dp box; the icon inside can be 24dp.
- Glass chrome often shrinks visually (transparent padding). Keep the interactive box.
- A 12dp gap between adjacent targets is enough; do not let glass margins eat it.

Checklist:

- [ ] Every `IconButton` / `IconToggleButton` has ≥ 48dp of touch area
- [ ] List item clickable spans the full row height (≥ 48dp)
- [ ] Small chips in a horizontal scroller are ≥ 48dp tall or have padded hit rects
- [ ] FAB and extended FAB: 56dp / 56dp min
- [ ] Custom `Slider` / `Toggle` thumb target ≥ 48dp

---

## 5. TalkBack

| Rule | Detail |
|------|--------|
| Every meaningful icon has a `contentDescription` | Decorative icons use `null` |
| Icon-only buttons describe the *action* | "Add to favourites", not "Star" |
| Group related content | `Modifier.semantics(mergeDescendants = true) { }` for a card that is one target |
| State is announced | Use `stateDescription` for toggles/expanded |
| Traversal order matches visual order | `isTraversalGroup` / `traversalIndex` for custom layouts |
| Custom actions | `CustomAccessibilityAction` for swipe gestures (e.g. swipe a card to delete) |
| Headings | `Modifier.semantics { heading() }` for section titles |
| Live regions | `liveRegion = LiveRegionMode.Polite` for a status that updates |
| Lists | `Modifier.semantics { collectionInfo(...) }` or use `LazyColumn` correctly |
| Progress | Announce the value; a spinning loader with no label is useless |
| Dialogs | Compose `Dialog` handles focus trapping; custom overlays must do it manually |

A glass surface must not break the accessibility tree. `hazeBlur` / `hazeGlass` must not swallow
semantics. If a blurred surface holds a `Surface` with a `containerColor`, the semantics come
from the surface, not from the blur modifier — the effect modifiers only change pixels.

**Test**: TalkBack must be able to reach and activate every control, and each control must
read sensibly with the screen reader's blur/transparency handling on.

---

## 6. Font scaling

- The app must support **200 %** font scale without losing function.
- Do not fix the height of text containers; let them grow.
- `TextUnit` in `sp`, never `dp`, for text sizes.
- `maxLines` + `overflow = TextOverflow.Ellipsis` is acceptable **only** where the truncated
  text has a detail screen, and the same info is reachable elsewhere.
- Chrome height (top bar, bottom bar) must grow with the text. A fixed 56dp app bar with
  22sp text at 200 % clips.
- Glass chrome is the most common clipping site: the blur container must not clip its
  content, and the tinted container must be tall enough to hold the grown text.
- Test with `fontScale` 1.0, 1.3, 1.5, 2.0 (`LocalDensity.current.fontScale`).
- Respect `LocalLayoutDirection` (RTL). `start`/`end` padding, not `left`/`right`.
- Respect display size / font size settings via `Configuration.fontScale`.

---

## 7. Motion design

### Springs, not tweens

Compose's expressive motion is spring-based.

```kotlin
val spatial = MaterialTheme.motionScheme.defaultSpatialSpec()
val effects = MaterialTheme.motionScheme.defaultEffectsSpec()

AnimatedVisibility(
    visible = expanded,
    enter = fadeIn(spatial) + expandVertically(spatial),
    exit = fadeOut(spatial) + shrinkVertically(spatial),
) { … }
```

| Scheme API | Use |
|-------------|-----|
| `defaultSpatialSpec()` | Position/size changes: expand, collapse, sheet, nav |
| `defaultEffectsSpec()` | Colour/alpha changes: fade, tint |
| `fastSpatialSpec()` / `fastEffectsSpec()` | Frequent, small transitions (≤ 200 ms) |
| `slowSpatialSpec()` / `slowEffectsSpec()` | Large surfaces, once-per-flow hero moments |

For `animate*AsState` (which takes a spring, not a spec) use `spring(dampingRatio, stiffness)`
with the values below.

### Choosing the right spring

| Intent | Spring | Feel |
|---------|--------|------|
| Small, quick UI response | `spring(dampingRatio = 1f, stiffness = 700f)` | Snappy, no overshoot |
| Medium movement (sheet, card) | `spring(dampingRatio = 0.9f, stiffness = 380f)` | Slight settle |
| Expressive / playful (hero) | `spring(dampingRatio = 0.6f, stiffness = 300f)` | Visible overshoot |
| Emphasized / spatial | `spring(dampingRatio = 0.9f, stiffness = 500f)` | Confident |
| Slow settle (large surfaces) | `spring(dampingRatio = 1f, stiffness = 200f)` | Calm |

Do not invent these numbers ad hoc — read them from the theme's `MotionScheme` so the whole
app shares one physics. Custom springs are a last resort and should be defined once, in the
theme, not sprinkled per screen.

### Timing rules

- Response < 100 ms feels instant (input → visual acknowledgement).
- Navigation transitions 250–400 ms.
- Expressive hero moments may reach 500–700 ms, but only once per flow.
- Never exceed 400 ms for a transition the user triggers repeatedly.

### What must NOT animate

- Scroll-linked chrome that jitters
- Layout shifts during text input
- Anything that blocks input
- Content that moves while the user is reading it

---

## 8. Other accessibility surfaces

| Concern | Action |
|---------|--------|
| Screen readers (TalkBack, Switch Access) | Full traversal + activation |
| Keyboard (physical/BT) | `focusable`, `onKeyEvent`, visible focus indicator |
| Pointer/trackpad | Hover + focus states distinct from pressed |
| Switch Access | Every action reachable as a scan step |
| Voice control | Visible labels matching the spoken command (e.g. "Add to favourites") |
| Magnification | No text clipped at 200 % zoom; allow scrolling |
| Colour vision deficiency | Don't rely on hue for state; check the error/success palette |
| Reduced data / battery | Degrade gracefully, not crash |

---

## 9. Accessibility gates before shipping

- [ ] TalkBack passes through every changed screen, in order, with sensible labels
- [ ] All interactive elements ≥ 48dp
- [ ] Body text ≥ 4.5:1, large text and icons ≥ 3:1 — **including over glass**
- [ ] Font scale 2.0 causes no clipping of text or controls
- [ ] Animation scale 0 → all transitions are instant, layout is final
- [ ] Reduce blur effects → app is fully legible with opaque fallbacks
- [ ] Dark theme → all surfaces and states are distinguishable
- [ ] RTL → layout mirrors correctly
- [ ] Keyboard navigation works with visible focus
- [ ] No information conveyed by colour alone
- [ ] Screen reader announces the correct state of every toggle/expandable
