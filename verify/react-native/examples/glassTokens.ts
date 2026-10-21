// React Native / Expo — glass tokens.
//
// Copy this first; the other files in this folder import it.
//
// The numbers here are the only place glass is configured. The reason is the
// same as on every other platform: an app that tunes blur per screen ends up
// with five different frosted looks and no way to change them together.

import type { BlurTint } from 'expo-blur';
import type { ColorValue } from 'react-native';

export type GlassTokens = {
  /** expo-blur intensity, 1–100. iOS reads this as material thickness. */
  intensity: number;
  /** The expo-blur tint. Every tint also adds a translucent colour layer. */
  tint: BlurTint;
  /** Corner radius in dp. 0 for bars that span the screen. */
  radius: number;
  /** The tint painted in the non-blurred fallback, so it still separates. */
  fallbackColor: string;
  /** 1 px edge light. */
  borderColor: string;
  /** Native iOS 26 glass tint. Undefined means "let the system decide". */
  nativeTint?: ColorValue;
};

/**
 * Chrome: headers, tab bars, the sheet header.
 *
 * `systemChromeMaterial` is the closest expo-blur tint to the platform's own
 * bar material on iOS. On Android the tint is approximated by the native blur
 * implementation, so expect it to read slightly differently — verify on device.
 */
export const glassChrome: GlassTokens = {
  intensity: 60,
  tint: 'systemChromeMaterial',
  radius: 0,
  fallbackColor: 'rgba(28, 27, 31, 0.92)',
  borderColor: 'rgba(255, 255, 255, 0.10)',
};

/** Floating objects: control groups, media controls, the FAB dock. */
export const glassFloating: GlassTokens = {
  intensity: 55,
  tint: 'systemMaterial',
  radius: 28,
  fallbackColor: 'rgba(38, 37, 43, 0.94)',
  borderColor: 'rgba(255, 255, 255, 0.14)',
};

/**
 * Android's blur implementation is weaker than iOS at the same intensity, and
 * expo-blur divides the value by this before handing it to the native view.
 */
export const androidBlurReductionFactor = 4;
