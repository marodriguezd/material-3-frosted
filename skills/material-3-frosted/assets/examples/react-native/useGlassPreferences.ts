// React Native — the blur switch, wired to the OS where the OS actually says
// something.
//
// This is the one place React Native is better off than Flutter: RN exposes
// `AccessibilityInfo.isReduceTransparencyEnabled()` and an iOS
// `'reduceTransparencyChanged'` event, so an app can honour Reduce Transparency
// without inventing its own setting.
//
// Android does not report it. `isReduceTransparencyEnabled()` resolves false
// there regardless of the system's "Remove animations"/blur preferences, so on
// Android this hook returns the app's own setting and nothing else. Do not
// assume otherwise — a bar that keeps blurring for a user who asked for less
// transparency is worse than one that never blurred.

import { useCallback, useEffect, useState } from 'react';
import { AccessibilityInfo, Platform } from 'react-native';

export type GlassPreferences = {
  /** Combine this with your own setting before passing it to GlassSurface. */
  reduceTransparency: boolean;
  /** False when the OS never reports the flag (Android), so UI can hide the copy. */
  systemReportsTransparency: boolean;
};

export function useGlassPreferences(): GlassPreferences {
  const [reduceTransparency, setReduceTransparency] = useState(false);

  const read = useCallback(async () => {
    try {
      setReduceTransparency(await AccessibilityInfo.isReduceTransparencyEnabled());
    } catch {
      // The API is iOS-only in practice; a rejection must not take the screen
      // down for a cosmetic setting.
      setReduceTransparency(false);
    }
  }, []);

  useEffect(() => {
    void read();
    const subscription = AccessibilityInfo.addEventListener(
      'reduceTransparencyChanged',
      setReduceTransparency,
    );
    return () => subscription.remove();
  }, [read]);

  return {
    reduceTransparency: Platform.OS === 'ios' ? reduceTransparency : false,
    systemReportsTransparency: Platform.OS === 'ios',
  };
}
