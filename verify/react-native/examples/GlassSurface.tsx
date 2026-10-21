// React Native / Expo — the glass primitive.
//
// Three backends, one component, because React Native genuinely has three:
//
//   1. iOS 26+      → expo-glass-effect's GlassView. This is the real system
//                     material, not an approximation of it.
//   2. iOS < 26     → expo-blur BlurView with a system material tint.
//   3. Android      → expo-blur BlurView, but ONLY if you set blurMethod.
//
// That third point is the trap. `expo-blur`'s `blurMethod` defaults to
// 'none', and the package documents it as: "Renders a semi-transparent view
// instead of rendering a blur effect." So the default Android build of a
// React Native frosted bar is a translucent rectangle — the exact failure this
// skill exists to prevent — and it looks fine in the iOS simulator.
//
// 'dimezisBlurViewSdk31Plus' is the setting to use: real blur on Android 12+,
// a translucent view below that, because the package's own docs warn about
// performance on older versions.

import type { ReactNode } from 'react';
import { Platform, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { BlurView } from 'expo-blur';
import {
  GlassView,
  isGlassEffectAPIAvailable,
  isLiquidGlassAvailable,
} from 'expo-glass-effect';

import { androidBlurReductionFactor, glassChrome, type GlassTokens } from './glassTokens';

export type GlassSurfaceProps = {
  children?: ReactNode;
  tokens?: GlassTokens;
  style?: StyleProp<ViewStyle>;
  /** Driven by the app's setting + the OS reduce-transparency flag. */
  blurEnabled?: boolean;
  /** Native iOS glass press response. Off for decorative surfaces. */
  isInteractive?: boolean;
};

/**
 * Whether this device can render the native iOS 26 glass material.
 *
 * `isLiquidGlassAvailable()` only reports that the *components* exist.
 * `isGlassEffectAPIAvailable()` checks the runtime API, which some iOS 26
 * builds shipped without — the package's own docs say to check it before
 * mounting GlassView or GlassContainer to avoid a crash. Both checks are
 * cheap; do both.
 */
export function canUseNativeGlass(): boolean {
  if (Platform.OS !== 'ios') return false;
  return isLiquidGlassAvailable() && isGlassEffectAPIAvailable();
}

export function GlassSurface({
  children,
  tokens = glassChrome,
  style,
  blurEnabled = true,
  isInteractive = false,
}: GlassSurfaceProps) {
  const radiusStyle: ViewStyle = { borderRadius: tokens.radius };

  // The fallback is not "the blur removed". It is a surface with its own
  // designed colour, still separated from the content behind it by the border.
  if (!blurEnabled) {
    return (
      <View
        style={[
          styles.surface,
          radiusStyle,
          { backgroundColor: tokens.fallbackColor, borderColor: tokens.borderColor },
          style,
        ]}
      >
        {children}
      </View>
    );
  }

  if (canUseNativeGlass()) {
    return (
      <GlassView
        glassEffectStyle="regular"
        tintColor={tokens.nativeTint}
        colorScheme="auto"
        isInteractive={isInteractive}
        style={[styles.surface, radiusStyle, { borderColor: tokens.borderColor }, style]}
      >
        {children}
      </GlassView>
    );
  }

  return (
    <BlurView
      intensity={tokens.intensity}
      tint={tokens.tint}
      // Without this Android renders a translucent view and no blur at all.
      blurMethod="dimezisBlurViewSdk31Plus"
      blurReductionFactor={androidBlurReductionFactor}
      style={[styles.surface, radiusStyle, { borderColor: tokens.borderColor }, style]}
    >
      {children}
    </BlurView>
  );
}

const styles = StyleSheet.create({
  surface: {
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
  },
});
