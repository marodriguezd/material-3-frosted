// Flutter — frosted glass tokens, theme, and the one switch that turns blur off.
//
// Copy this file first: every other example in this folder consumes it.
//
// The hard truth about Flutter glass that this file exists to handle:
//
//   Flutter does NOT expose the platform's "reduce transparency" / "remove blur"
//   setting. `AccessibilityFeatures` has accessibleNavigation, invertColors,
//   disableAnimations, boldText, reduceMotion, highContrast, ... and no
//   transparency flag. So an app that wants to respect that user preference has
//   to own an in-app switch and persist it. `FrostedGlassScope` is that switch.

import 'package:flutter/material.dart';

/// One glass recipe: how much to blur, what to tint it with, how to edge it.
///
/// Keep the count low. There are two presets for a reason — a third one is how
/// designs start looking like a glassmorphism demo instead of Material 3.
@immutable
class GlassStyle {
  const GlassStyle({
    required this.blurSigma,
    required this.tint,
    required this.border,
    required this.radius,
  });

  /// Standard deviation of the Gaussian kernel. 20–30 dp is the range that
  /// reads as frosted rather than "smudged". Above ~40 the content behind is
  /// gone and you have an expensive opaque bar.
  final double blurSigma;

  /// The tint painted over the blur. Never fully transparent: the blur is a
  /// *fallback-dependent* effect, and the tint is what keeps text legible when
  /// blur is disabled.
  final Color tint;

  /// The 1 px edge light. This is what makes glass read as a surface with a
  /// thickness instead of a hole in the screen.
  final Color border;

  final double radius;

  /// Chrome: app bars, navigation bars, the sheet header.
  static GlassStyle chrome(ColorScheme scheme) => GlassStyle(
    blurSigma: 24,
    tint: scheme.surfaceContainerLow.withValues(alpha: 0.55),
    border: scheme.outlineVariant.withValues(alpha: 0.45),
    radius: 0,
  );

  /// Floating objects: FAB docks, chips, media controls.
  static GlassStyle floating(ColorScheme scheme) => GlassStyle(
    blurSigma: 20,
    tint: scheme.surfaceContainerHigh.withValues(alpha: 0.70),
    border: scheme.outlineVariant.withValues(alpha: 0.55),
    radius: 28,
  );

  /// Same recipe with a different tint, for a surface that sits on media.
  GlassStyle withTint(Color color) => GlassStyle(
    blurSigma: blurSigma,
    tint: color,
    border: border,
    radius: radius,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassStyle &&
      other.blurSigma == blurSigma &&
      other.tint == tint &&
      other.border == border &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(blurSigma, tint, border, radius);
}

/// Descendants read the glass tokens and the user's blur preference from here.
///
/// An `InheritedWidget` rather than a package: this is the "one theme source of
/// truth" rule from the migration playbook, and it costs 40 lines.
class FrostedGlassScope extends InheritedWidget {
  const FrostedGlassScope({
    super.key,
    required this.style,
    required this.blurEnabled,
    required this.onBlurEnabledChanged,
    required super.child,
  });

  final GlassStyle style;

  /// When false, every [GlassSurface] paints only its tint and border.
  ///
  /// That is a *designed* state, not a degraded one: an app whose chrome is
  /// unreadable without blur is unreadable for everyone who turns it off.
  final bool blurEnabled;

  /// `null` in apps that do not offer the switch (a demo, a kiosk build).
  final ValueChanged<bool>? onBlurEnabledChanged;

  static FrostedGlassScope of(BuildContext context) {
    final FrostedGlassScope? scope =
        context.dependOnInheritedWidgetOfExactType<FrostedGlassScope>();
    assert(scope != null, 'No FrostedGlassScope above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(FrostedGlassScope oldWidget) =>
      oldWidget.style != style || oldWidget.blurEnabled != blurEnabled;
}

/// The expressive foundation the glass sits on.
///
/// Flutter's Material 3 is not the Compose `material3` artifact: there is no
/// `MaterialExpressiveTheme`, no `MotionScheme`, and no `Shapes.largeIncreased`.
/// What you get — verified against the SDK in `flutter/lib/src/material` — is
/// `useMaterial3` (true by default), `ColorScheme.fromSeed`, the M3 component
/// set, and full control of type and shape through `ThemeData`.
ThemeData frostedTheme({
  required Brightness brightness,
  Color seedColor = const Color(0xFF6E56CF),
  ColorScheme? colorScheme,
}) {
  final ColorScheme scheme =
      colorScheme ??
      ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

  final ThemeData base = ThemeData(colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    // Emphasized title: the single highest-value typographic change.
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    // Chrome is transparent and the glass is the container. Setting a colour
    // here would paint over the blur and the effect would silently vanish.
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
    ),
    // `ThemeData.bottomSheetTheme` — not `sheetTheme`, which does not exist.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black54,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
    // Expressive-ish friction: the shape scale leans on full-round controls.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
      ),
    ),
  );
}

/// Drop-in app shell: theme + scope + the blur switch.
///
/// In a real app the switch belongs in settings and its value in
/// `SharedPreferences`; here it is state so the example runs on its own.
class FrostedApp extends StatefulWidget {
  const FrostedApp({
    super.key,
    required this.home,
    this.seedColor = const Color(0xFF6E56CF),
    this.darkMode = false,
  });

  final Widget home;
  final Color seedColor;
  final bool darkMode;

  @override
  State<FrostedApp> createState() => _FrostedAppState();
}

class _FrostedAppState extends State<FrostedApp> {
  bool _blurEnabled = true;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = widget.darkMode
        ? Brightness.dark
        : Brightness.light;

    // One theme, one scheme: the glass tokens are derived from the same colour
    // scheme the widgets use, so a seed-colour change moves both together.
    final ThemeData theme = frostedTheme(
      brightness: brightness,
      seedColor: widget.seedColor,
    );

    return FrostedGlassScope(
      style: GlassStyle.chrome(theme.colorScheme),
      blurEnabled: _blurEnabled,
      onBlurEnabledChanged: (bool value) =>
          setState(() => _blurEnabled = value),
      child: MaterialApp(
        title: 'Frosted',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: widget.home,
      ),
    );
  }
}
