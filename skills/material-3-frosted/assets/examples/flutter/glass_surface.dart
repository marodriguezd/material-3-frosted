// Flutter — the one primitive every glass surface in the app should use.
//
// Four things in here are the difference between real frosted glass and the
// blurry rectangle that most Flutter apps ship. Each is a verified API detail,
// not a preference:
//
// 1. `BackdropFilter` filters "the existing painted content", clipped to its
//    parent. With no clip it filters the WHOLE SCREEN. So the clip is not
//    cosmetic — omit it and your 56 dp app bar frosts the entire viewport.
//
// 2. `ImageFilterConfig.blur(bounded: true)` is the layout-aware blur. The SDK
//    documents it as "typically used to replicate the high-fidelity frosted
//    glass effect seen on iOS": it samples only inside the object's bounds, so
//    adjacent content cannot bleed colour into the pane. The classic
//    `filter: ImageFilter.blur(...)` path samples the whole canvas and is why
//    hand-rolled glass looks muddy at the edges.
//
// 3. `BackdropFilter.grouped` shares one backdrop input with every other
//    grouped filter under the same `BackdropGroup`. The engine then performs
//    the filtering once instead of N times. This is Flutter's equivalent of the
//    clustering API Haze does not have in 2.0.1 — and it comes with the same
//    warning: filters that OVERLAP must not share a key, or the overlap looks
//    like a single filter.
//
// 4. `enabled: false` is the supported way to disable the effect. The SDK says
//    to prefer it over a "no-op" filter for performance. That is the fallback
//    path, and it must still look deliberate.

import 'package:flutter/material.dart';

import 'glass_theme.dart';

/// A frosted pane: blur + tint + edge, clipped to a rounded rectangle.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.child,
    this.style,
    this.radius,
    this.blendMode = BlendMode.srcOver,
    this.padding,
  });

  final Widget? child;

  /// Defaults to the scope's chrome style.
  final GlassStyle? style;

  /// Overrides [GlassStyle.radius]. Use `0` for bars that span the screen.
  final double? radius;

  /// Only change this when the pane sits inside a save layer — an `Opacity`
  /// above it makes `BlendMode.srcOver` composite oddly; `BlendMode.src` reads
  /// better there.
  final BlendMode blendMode;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final FrostedGlassScope scope = FrostedGlassScope.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GlassStyle style = this.style ?? scope.style;
    final double resolvedRadius = radius ?? style.radius;
    final BorderRadius shape = BorderRadius.circular(resolvedRadius);

    // With the blur off the pane must still separate from the content behind
    // it. Blending the tint over an opaque container role gives a flat surface
    // that matches the frosted one's hue, so switching the setting is a change
    // of texture, not a change of design.
    final Color fill = scope.blurEnabled
        ? style.tint
        : Color.alphaBlend(style.tint, scheme.surfaceContainer);

    final Widget? content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    // The filter stays in the tree in both states: `enabled` makes the engine
    // skip the work without changing the widget tree, so toggling cannot cause
    // a layout jump or a rebuild storm.
    return ClipRRect(
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter.grouped(
        filterConfig: ImageFilterConfig.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
          bounded: true,
        ),
        blendMode: blendMode,
        enabled: scope.blurEnabled,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: style.border),
            borderRadius: resolvedRadius > 0 ? shape : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Put one of these above a screen whose glass surfaces should share a backdrop.
///
/// The win is real: N grouped filters over one shared backdrop cost one
/// filtering pass. The catch is the one the SDK documents — surfaces that
/// overlap each other must live in different groups, because a shared key makes
/// the overlap behave as if only one filter were applied.
class GlassGroup extends StatelessWidget {
  const GlassGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BackdropGroup(child: child);
}

/// A glass bar that still hosts `Material`.
///
/// Ink splashes, semantics and M3 text styles all come from `Material`; it is
/// made transparent so the backdrop survives. Replacing it with a plain
/// `Container` is how glass bars lose their ripples and their contrast.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.height,
    this.style,
    this.borderRadius,
  });

  final Widget child;
  final double? height;
  final GlassStyle? style;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: GlassSurface(
        style: style,
        radius: borderRadius ?? 0,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
