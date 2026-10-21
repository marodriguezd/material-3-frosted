# React Native / Expo

React Native has three different glass backends depending on the OS, and the one most apps get
by default is *not a blur*. Everything here was read from the published package typings —
`expo-blur@58.0.5` and `expo-glass-effect@58.0.4` — and the examples in
`assets/examples/react-native/` are typechecked against them with `tsc --strict`.

---

## 1. The Android default is not a blur

This is the single most useful thing in this file.

`expo-blur`'s `blurMethod` prop:

> `'none'` — Renders a semi-transparent view instead of rendering a blur effect.

> **`@default 'none'`**

So a `<BlurView intensity={60} tint="systemChromeMaterial" />` with no `blurMethod` renders a
translucent rectangle on Android. It looks right in the iOS simulator, which is where most of
this code gets written, and it is not frosted glass.

The full type, verified:

```ts
export type BlurMethod = 'none' | 'dimezisBlurView' | 'dimezisBlurViewSdk31Plus';
```

Use `'dimezisBlurViewSdk31Plus'`: real blur on Android 12+, translucent view below that, because
the package's own docs say `'dimezisBlurView'` "may lead to decreased performance on Android SDK
30 and below". `experimentalBlurMethod` is deprecated — do not use it.

```tsx
<BlurView
  intensity={60}
  tint="systemChromeMaterial"
  blurMethod="dimezisBlurViewSdk31Plus"
  blurReductionFactor={4}
/>
```

`blurReductionFactor` (Android, default `4`) divides the intensity for the native view, because
the same number does not produce the same amount of blur on the two platforms. Expect to tune it
on a real device.

---

## 2. iOS 26 gets the real material

`expo-glass-effect` wraps the system's Liquid Glass. Verified props:

```ts
type GlassStyle = 'clear' | 'regular' | 'none';

type GlassViewProps = {
  glassEffectStyle?: GlassStyle | { style: GlassStyle; animate?: boolean; animationDuration?: number };
  tintColor?: ColorValue;
  isInteractive?: boolean;      // default false
  colorScheme?: 'auto' | 'light' | 'dark';   // default 'auto'
};

type GlassContainerProps = { spacing?: number };
```

`GlassContainer`'s `spacing` is documented as "the distance at which glass elements start
affecting each other. Controls when glass elements begin to merge together." That is the
clustering behaviour — the equivalent of Haze's `hazeGlassContainer`, which does not exist in
Haze 2.0.1, and of Flutter's `BackdropGroup`.

Two availability checks, and they are not the same:

```ts
isLiquidGlassAvailable(): boolean       // are the components available at all
isGlassEffectAPIAvailable(): boolean    // is the runtime API present (some iOS 26 builds lack it)
```

The package's docs are explicit that you should check the second before mounting `GlassView` or
`GlassContainer`, because some iOS 26 beta builds crash without it. Check both; they are cheap.

---

## 3. Reduce Transparency is available here

React Native exposes it, unlike Flutter:

```ts
AccessibilityInfo.isReduceTransparencyEnabled(): Promise<boolean>
AccessibilityInfo.addEventListener('reduceTransparencyChanged', handler): EmitterSubscription
```

Both verified in `react-native@0.83`'s typings. The event is iOS-only; on Android the query
resolves `false` regardless of the system's blur preferences. So:

- iOS: honour the OS flag, live.
- Android: own the switch, as on every other platform.

`assets/examples/react-native/useGlassPreferences.ts` implements both halves.

---

## 4. Composition

Same topology as everywhere else, expressed with RN's layout:

```tsx
<View>
  <ScrollView>{/* 1. content — painted first, this is the backdrop */}</ScrollView>
  <GlassHeader />            {/* 2. absolute, after content */}
  <View style={styles.tabSlot}><GlassTabBar /></View>
</View>
```

`ScrollView` does not clip in a way that helps; the blur surface itself must have
`overflow: 'hidden'` and a `borderRadius`, which `GlassSurface` does.

Rules that carry over unchanged: chrome yes, content no; glass count per screen ≤ 3; the tint
must stand alone when the blur is off.

What is different:

- **There is no per-widget grouping on Android.** `GlassContainer` is iOS 26 only. On Android and
  on older iOS, a group of glass controls is N independent blur layers, so merge them into one
  pane containing the controls. That is what `GlassControlGroup` does.
- **`BlurTargetView` + `blurTarget`.** The Android blur takes a ref to the view it should blur.
  Useful when the default (the whole screen behind it) is too expensive or blurs the wrong
  subtree.

---

## 5. Material 3 in React Native

There is no first-party Material 3. In practice:

- `react-native-paper` provides M3 components and a `PaperProvider` theme (seed colours included).
- Tokens you still own: the shape scale, the emphasized `titleLarge` (22 / line-height 28 / `600`),
  and the reduced-motion behaviour (`AccessibilityInfo.isReduceMotionEnabled()`).
- Springs: `Animated.spring` with `stiffness`/`damping`/`mass`, or Reanimated's `withSpring` — both
  are real springs, unlike a `duration` + `easing` tween.

The examples deliberately have zero dependencies beyond `expo-blur`/`expo-glass-effect` and inline
the Material 3 baseline palette, so you can drop them into any RN app whether or not it uses
Paper.

---

## 6. Anti-patterns

| Symptom | Cause | Fix |
|---|---|---|
| No blur on Android, fine on iOS | `blurMethod` defaults to `'none'` | `blurMethod="dimezisBlurViewSdk31Plus"` |
| Crash on iOS 26 | `GlassView` mounted without `isGlassEffectAPIAvailable()` | Check both availability functions |
| Blur looks weaker on Android | Same `intensity` means different things per platform | Tune `blurReductionFactor` on device |
| Bar blurs nothing | Content is a sibling painted *after* the bar | Paint content first, chrome second |
| Blur ignores rounded corners | `overflow: 'hidden'` missing on the blurred view | Add it in the surface style |
| Unreadable with Reduce Transparency on | Fallback colour never designed | Design the opaque state first |

---

## 7. Checklist

- [ ] `blurMethod` set on every `BlurView`.
- [ ] `isLiquidGlassAvailable()` **and** `isGlassEffectAPIAvailable()` before native glass.
- [ ] `accessibilityReduceTransparency` honoured on iOS; app-owned setting on Android.
- [ ] Glass groups merged into one pane where `GlassContainer` is unavailable.
- [ ] Chrome painted after content.
- [ ] Glass count per screen ≤ 3.
- [ ] `tsc --noEmit` clean.
