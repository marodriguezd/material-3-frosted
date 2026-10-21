// React Native — the four chrome surfaces that are allowed to be glass.
//
// The placement rule is identical to the Compose path: chrome yes, content no.
// What changes is the API you express it with.
//
// `GlassContainer` is worth calling out. On iOS 26 it is the merging primitive:
// its `spacing` prop is "the distance at which glass elements start affecting
// each other", i.e. two controls that are close enough blend into one optical
// object. That is the behaviour Haze 2.0.1 does not ship and Flutter only
// approximates with a shared backdrop key. Use it for groups of 2–3 controls.
//
// Everywhere else, a group of glass controls is N independent blur layers, so
// merge them into ONE pane containing the controls instead.

import type { ReactNode } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { GlassContainer } from 'expo-glass-effect';

import { GlassSurface, canUseNativeGlass } from './GlassSurface';
import { glassChrome, glassFloating, type GlassTokens } from './glassTokens';

/** A frosted header that sits over scrolling content. */
export function GlassHeader({
  title,
  right,
  blurEnabled = true,
}: {
  title: string;
  right?: ReactNode;
  blurEnabled?: boolean;
}) {
  return (
    <GlassSurface tokens={glassChrome} blurEnabled={blurEnabled} style={styles.header}>
      <View style={styles.headerRow}>
        <Text style={styles.headerTitle} numberOfLines={1}>
          {title}
        </Text>
        {right}
      </View>
    </GlassSurface>
  );
}

/** A frosted tab bar. Top-level destinations only. */
export function GlassTabBar({
  items,
  activeIndex,
  onSelect,
  blurEnabled = true,
}: {
  items: readonly string[];
  activeIndex: number;
  onSelect: (index: number) => void;
  blurEnabled?: boolean;
}) {
  return (
    <GlassSurface tokens={glassChrome} blurEnabled={blurEnabled}>
      <View style={styles.tabRow}>
        {items.map((label, index) => (
          <Pressable
            key={label}
            accessibilityRole="tab"
            accessibilityState={{ selected: index === activeIndex }}
            accessibilityLabel={label}
            onPress={() => onSelect(index)}
            style={styles.tabItem}
          >
            <View
              style={[
                styles.tabIndicator,
                index === activeIndex && styles.tabIndicatorActive,
              ]}
            />
            <Text style={styles.tabLabel} numberOfLines={1}>
              {label}
            </Text>
          </Pressable>
        ))}
      </View>
    </GlassSurface>
  );
}

/**
 * A group of glass controls.
 *
 * iOS 26: a real `GlassContainer`, so the members merge into one object.
 * Elsewhere: one pane around the whole row, because separate panes would be
 * separate blur passes for no visual gain.
 */
export function GlassControlGroup({
  children,
  blurEnabled = true,
  spacing = 8,
}: {
  children: ReactNode;
  blurEnabled?: boolean;
  spacing?: number;
}) {
  if (canUseNativeGlass()) {
    return (
      <GlassContainer spacing={spacing} style={styles.groupRow}>
        {children}
      </GlassContainer>
    );
  }

  return (
    <GlassSurface
      tokens={glassFloating}
      blurEnabled={blurEnabled}
      style={styles.groupPane}
    >
      <View style={[styles.groupRow, { gap: spacing }]}>{children}</View>
    </GlassSurface>
  );
}

/** A glass chip, for use inside a {@link GlassControlGroup}. */
export function GlassChip({
  label,
  selected,
  onPress,
  blurEnabled = true,
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
  blurEnabled?: boolean;
}) {
  const content = (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      onPress={onPress}
      style={styles.chip}
    >
      <Text style={[styles.chipLabel, selected && styles.chipLabelSelected]}>{label}</Text>
    </Pressable>
  );

  // Inside a native GlassContainer the chip must itself be native glass for the
  // merging to happen; there the group already supplies the surface.
  if (canUseNativeGlass()) {
    return <GlassSurface tokens={glassFloating} blurEnabled={blurEnabled}>{content}</GlassSurface>;
  }
  return content;
}

/**
 * A floating dock: one glass quick action plus the primary action.
 *
 * The primary action is deliberately NOT glass. A translucent primary CTA loses
 * the prominence its colour earns, and it is the one control on the screen that
 * must never be ambiguous.
 */
export function GlassFabDock({
  onPrimary,
  onSecondary,
  blurEnabled = true,
  tokens = glassFloating,
}: {
  onPrimary: () => void;
  onSecondary?: () => void;
  blurEnabled?: boolean;
  tokens?: GlassTokens;
}) {
  return (
    <View style={styles.dock}>
      {onSecondary ? (
        <GlassSurface tokens={tokens} blurEnabled={blurEnabled}>
          <Pressable accessibilityRole="button" accessibilityLabel="Search" onPress={onSecondary} style={styles.dockButton}>
            <Text style={styles.dockButtonLabel}>⌕</Text>
          </Pressable>
        </GlassSurface>
      ) : null}
      <Pressable accessibilityRole="button" accessibilityLabel="Add" onPress={onPrimary} style={styles.fab}>
        <Text style={styles.fabLabel}>+</Text>
      </Pressable>
    </View>
  );
}

/** True when the platform renders the real native glass, for feature copy. */
export const hasNativeGlass = Platform.OS === 'ios' && canUseNativeGlass();

const styles = StyleSheet.create({
  header: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    paddingTop: 12,
    paddingBottom: 12,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    minHeight: 32,
  },
  headerTitle: { fontSize: 22, fontWeight: '600', color: '#E6E1E9' },
  tabRow: { flexDirection: 'row', paddingVertical: 6 },
  tabItem: { flex: 1, alignItems: 'center', paddingVertical: 6, gap: 6 },
  tabIndicator: { width: 24, height: 3, borderRadius: 2, backgroundColor: 'transparent' },
  tabIndicatorActive: { backgroundColor: '#D0BCFF' },
  tabLabel: { fontSize: 12, color: '#CAC4D0' },
  groupPane: { padding: 4 },
  groupRow: { flexDirection: 'row', alignItems: 'center' },
  chip: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 999 },
  chipLabel: { fontSize: 14, color: '#CAC4D0' },
  chipLabelSelected: { color: '#1C1B1F', fontWeight: '600' },
  dock: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  dockButton: { width: 56, height: 56, alignItems: 'center', justifyContent: 'center' },
  dockButtonLabel: { fontSize: 22, color: '#E6E1E9' },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#D0BCFF',
  },
  fabLabel: { fontSize: 24, color: '#1C1B1F' },
});
