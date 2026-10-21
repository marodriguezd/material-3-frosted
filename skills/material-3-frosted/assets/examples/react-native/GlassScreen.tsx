// React Native — a whole screen: glass chrome over opaque content.
//
// Layout is the same story as every other platform, with RN's own twist: the
// content is a ScrollView, the chrome is absolutely positioned siblings AFTER
// it in the tree. A backdrop blur samples whatever is already rendered behind
// it, so order in the JSX is the topology.
//
// Content stays opaque. Every row below is a solid surface — the glass is the
// header, the tab bar and the dock.

import { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, View, useColorScheme } from 'react-native';

import {
  GlassChip,
  GlassControlGroup,
  GlassFabDock,
  GlassHeader,
  GlassTabBar,
} from './GlassChrome';
import { useGlassPreferences } from './useGlassPreferences';

const TABS = ['Library', 'Search', 'Settings'] as const;
const FILTERS = ['Day', 'Week', 'Month'] as const;

export function GlassScreen() {
  const scheme = useColorScheme();
  const [tab, setTab] = useState(0);
  const [filter, setFilter] = useState(0);

  // One place decides whether blur is on: the OS setting on iOS, plus (in a
  // real app) the user's own toggle, which you must persist yourself because
  // Android never reports the system preference.
  const { reduceTransparency } = useGlassPreferences();
  const blurEnabled = !reduceTransparency;

  const colors = useMemo(
    () =>
      scheme === 'dark'
        ? { background: '#141218', surface: '#1D1B20', text: '#E6E1E9', muted: '#CAC4D0' }
        : { background: '#FEF7FF', surface: '#F7F2FA', text: '#1D1B20', muted: '#49454F' },
    [scheme],
  );

  const rows = useMemo(
    () => Array.from({ length: 40 }, (_, index) => `Item ${index}`),
    [],
  );

  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      {/* 1. Content, painted first: this is the backdrop the chrome samples. */}
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.controls}>
          <GlassControlGroup blurEnabled={blurEnabled}>
            {FILTERS.map((label, index) => (
              <GlassChip
                key={label}
                label={label}
                selected={index === filter}
                onPress={() => setFilter(index)}
                blurEnabled={blurEnabled}
              />
            ))}
          </GlassControlGroup>
        </View>

        {rows.map((row) => (
          <View
            key={row}
            style={[styles.row, { backgroundColor: colors.surface }]}
          >
            <Text style={[styles.rowText, { color: colors.text }]}>{row}</Text>
            <Text style={[styles.rowMeta, { color: colors.muted }]}>18 min</Text>
          </View>
        ))}
      </ScrollView>

      {/* 2. Chrome: siblings painted after the content. */}
      <GlassHeader title={TABS[tab]} blurEnabled={blurEnabled} />
      <View style={styles.dockSlot}>
        <GlassFabDock
          blurEnabled={blurEnabled}
          onPrimary={() => setTab(0)}
          onSecondary={() => setTab(1)}
        />
      </View>
      <View style={styles.tabSlot}>
        <GlassTabBar
          items={TABS}
          activeIndex={tab}
          onSelect={setTab}
          blurEnabled={blurEnabled}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { paddingTop: 96, paddingBottom: 160, paddingHorizontal: 16, gap: 8 },
  controls: { alignItems: 'flex-start', marginBottom: 8 },
  row: {
    borderRadius: 16,
    paddingHorizontal: 16,
    paddingVertical: 18,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  rowText: { fontSize: 16 },
  rowMeta: { fontSize: 13 },
  dockSlot: { position: 'absolute', right: 16, bottom: 96 },
  tabSlot: { position: 'absolute', left: 0, right: 0, bottom: 0 },
});
