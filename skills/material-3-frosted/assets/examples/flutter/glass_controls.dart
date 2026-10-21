// Flutter — glass controls: a segmented control in one pane, and a FAB dock.
//
// The rule this file demonstrates is the opposite of the intuitive one:
//
//   One wide glass surface beats several small ones.
//
// `BackdropFilter.grouped` does let you share one backdrop input across N
// filters, and the engine will filter once. But each grouped filter still
// paints, samples and composites its own region, and each one has to be
// positioned, clipped and hit-tested independently. A segmented control with
// three glass segments is three of everything. The same control inside one
// glass pane is one.
//
// So: group the filters you cannot avoid (a bar plus a nearby floating chip),
// and merge the ones you can (the segments of a control) into a single pane.

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_theme.dart';

/// A segmented control sitting on one glass pane.
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool multiSelectionEnabled;
  final bool emptySelectionAllowed;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      style: GlassStyle.floating(Theme.of(context).colorScheme),
      // The pane is the container; the control inside is a normal M3 control
      // with its own colour semantics. Glass is the container, never the button.
      padding: const EdgeInsets.all(4),
      child: SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        multiSelectionEnabled: multiSelectionEnabled,
        emptySelectionAllowed: emptySelectionAllowed,
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
        ),
      ),
    );
  }
}

/// A floating cluster: a FAB plus a quick action, sharing one backdrop.
///
/// This is the case `BackdropFilter.grouped` is actually for — two controls that
/// are adjacent but do not overlap. `GlassGroup` gives them one filtering pass.
/// Put them in the same group as the navigation bar and the overlap rule is on
/// your side, not against you: the bar is at the bottom, the dock sits above it.
class GlassFabDock extends StatelessWidget {
  const GlassFabDock({
    super.key,
    required this.onPrimaryAction,
    this.secondaryAction,
    this.secondaryIcon = Icons.search,
    this.secondaryTooltip = 'Search',
  });

  final VoidCallback onPrimaryAction;
  final VoidCallback? secondaryAction;
  final IconData secondaryIcon;
  final String secondaryTooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GlassStyle style = GlassStyle.floating(scheme);

    return GlassGroup(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (secondaryAction != null) ...<Widget>[
            GlassSurface(
              style: style,
              child: IconButton.filledTonal(
                tooltip: secondaryTooltip,
                icon: Icon(secondaryIcon),
                onPressed: secondaryAction,
              ),
            ),
            const SizedBox(width: 12),
          ],
          // The primary action is NOT glass. A translucent primary CTA loses the
          // prominence the FAB colour earns, and it is the one control on this
          // row that must never be ambiguous.
          FloatingActionButton(
            onPressed: onPrimaryAction,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
