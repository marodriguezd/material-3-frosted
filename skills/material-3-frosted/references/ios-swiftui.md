# iOS / SwiftUI

SwiftUI is the platform where frosted glass is not an approximation: the system material is the
same one the OS chrome uses, and on iOS 26 the Liquid Glass API is public. That makes the SwiftUI
path shorter than the Compose and Flutter ones — and it makes the *fallback* the hard part,
because on iOS you have a real user setting to honour.

**Verification status.** The example in `assets/examples/ios-swiftui/` is typechecked against the
iOS SDK on a macOS runner in CI (`swiftc -typecheck`). There is no Swift toolchain on the machine
that maintains this skill, so nothing here was verified locally — if a claim in this file and the
compiler disagree, the compiler is right, and that is what the CI job is for.

---

## 1. The materials

SwiftUI ships the system materials; you do not build a blur.

```swift
.background(.ultraThinMaterial)
.background(.regularMaterial, in: .rect(cornerRadius: 28))
```

| Material | Reads as |
|---|---|
| `.ultraThinMaterial` | Barely there; the content behind is clearly legible |
| `.thinMaterial` | Light frost |
| `.regularMaterial` | The default for floating surfaces |
| `.thickMaterial` / `.ultraThickMaterial` | Nearly opaque; use when contrast matters more than depth |
| `.bar` | The material the system bars use — the right choice for navigation chrome |

`.background(_:in:fillStyle:)` takes a `Shape`, so rounded corners come for free and are clipped
correctly. That is the equivalent of the `ClipRRect` requirement in Flutter: without a shape, the
material fills the whole frame.

Two habits that prevent the usual problems:

- **Stroke the edge.** A 0.5 pt `strokeBorder` at ~8 % of the primary colour is what makes the
  surface read as having thickness. Without it, light-on-light content makes the bar disappear.
- **Never make the tint fully transparent.** With Reduce Transparency on, the tint *is* the
  surface.

---

## 2. iOS 26: Liquid Glass

On iOS 26 the system exposes the real material:

```swift
if #available(iOS 26.0, *) {
    shape.fill(.clear)
        .glassEffect(.regular.tint(tint), in: shape)
}
```

and the merging container:

```swift
GlassEffectContainer(spacing: 8) {
    HStack(spacing: 8) { controls }
}
```

`GlassEffectContainer` is the clustering primitive: elements within `spacing` merge into one
optical object instead of reading as separate panes. Same concept as Flutter's `BackdropGroup` and
React Native's `GlassContainer` — and the one thing Haze 2.0.1 does not have.

Practical advice for the transition period: **keep the pre-26 path on screen.** Most devices will
not be on 26 for a while, and an app whose chrome is unreadable there has a bug, not a fallback.
Guard with `if #available`, and make sure both branches use the same shape, padding and border so
switching OS version is a change of texture only.

---

## 3. Reduce Transparency — this is not optional

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
```

When it is true, do not blur and do not leave a translucent rectangle. Fill with an opaque system
colour in the same hue and keep the border. The setting exists because transparency causes real
problems for some users; ignoring it is a defect, not a style choice.

Also wire:

- `@Environment(\.accessibilityReduceMotion)` — skip the merge and morph animations.
- `@Environment(\.colorSchemeContrast)` — `.increased` means raise the tint and the border alpha.

`assets/examples/ios-swiftui/GlassChrome.swift` reads `accessibilityReduceTransparency` and
branches the fill, so the three states (native glass / material / opaque) share one layout.

---

## 4. Bars: use `safeAreaInset`

```swift
content.safeAreaInset(edge: .top, spacing: 0) { glassBar }
content.safeAreaInset(edge: .bottom, spacing: 0) { glassTabBar }
```

`safeAreaInset` inserts the bar into the safe area, so the scroll view gets the right content
inset automatically and the content scrolls *under* the bar. Building this by hand with a `ZStack`
plus manual padding is where "the last row is hidden behind the tab bar" comes from.

Two consequences worth knowing:

- The bar's height grows with Dynamic Type if you let the label wrap; that is correct behaviour.
  Do not fix the height.
- `.toolbar` with `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)` is the *other*
  valid route when you are already inside a `NavigationStack`. Use it when the bar is a real
  toolbar; use `safeAreaInset` when you need a custom bar.

---

## 5. When SwiftUI is not enough

`Material` and `.glassEffect` cover chrome. They do not give you refraction control, custom blur
radius, or progressive blur. If you need those:

- Wrap `UIVisualEffectView` in a `UIViewRepresentable` — you get the same material but with
  direct control of the effect view and its `UIVisualEffectView.Effect`.
- For refraction-grade effects you are writing Metal or a Core Image pipeline. That is a
  different project; do not start there for a bar.

---

## 6. Placement

Identical to every other target in this skill:

- **Tier 1 (glass):** navigation bar, tab bar, sheet header, floating controls, a segmented
  control's container.
- **Tier 2 (with a reason):** media overlays, hero controls over imagery.
- **Tier 3 (never):** body text, list rows, forms, full-screen scrims, primary CTAs.

The iOS-specific trap is `.glassEffect` on everything because it is one modifier. Glass on a
`List` row makes the row's own content unreadable as it scrolls, and the system will not stop you.

---

## 7. Checklist

- [ ] `Material` used for chrome; `.bar` for navigation bars.
- [ ] iOS 26 path behind `if #available`, with the pre-26 path designed, not improvised.
- [ ] `accessibilityReduceTransparency` honoured with an opaque, same-hue fill.
- [ ] `accessibilityReduceMotion` honoured for merges and morphs.
- [ ] Bars inserted with `safeAreaInset` (or a real `.toolbar`).
- [ ] `strokeBorder` on every glass surface.
- [ ] Glass count per screen ≤ 3, and content stays opaque.
- [ ] The example typechecks against the iOS SDK in CI.
