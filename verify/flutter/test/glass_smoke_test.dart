// These tests run the shipped examples. `flutter analyze` proves the APIs
// exist; this proves the widgets actually build, lay out, respond to input and
// survive the fallback path. Both are needed: a widget can typecheck and still
// throw on its first layout pass.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_3_frosted_verify/examples/glass_controls.dart';
import 'package:material_3_frosted_verify/examples/glass_scaffold.dart';
import 'package:material_3_frosted_verify/examples/glass_sheet.dart';
import 'package:material_3_frosted_verify/examples/glass_surface.dart';
import 'package:material_3_frosted_verify/examples/glass_theme.dart';

Widget _host(Widget child) => FrostedApp(home: child);

Widget _scaffold() => GlassScaffold(
  title: 'Library',
  destinations: const <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
  ],
  body: ListView.builder(
    itemCount: 40,
    itemBuilder: (BuildContext context, int index) => ListTile(
      title: Text('Item $index'),
    ),
  ),
);

void main() {
  testWidgets('scaffold builds with glass chrome', (WidgetTester tester) async {
    await tester.pumpWidget(_host(_scaffold()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Item 0'), findsOneWidget);

    // One glass surface for the app bar and one for the navigation bar.
    expect(find.byType(GlassBar), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('app bar is hidden until the content scrolls under it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_scaffold()));
    await tester.pumpAndSettle();

    final Finder appBarFade = find.ancestor(
      of: find.byType(GlassBar),
      matching: find.byType(AnimatedOpacity),
    );
    expect(appBarFade, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(appBarFade).opacity, 0.0);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(appBarFade).opacity, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning blur off keeps every surface in the tree, disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_scaffold()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The toggle lives in the app bar, which is only visible once scrolled.
    await tester.tap(find.byTooltip('Turn blur off'));
    await tester.pumpAndSettle();

    final Iterable<BackdropFilter> filters = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter));
    expect(filters, isNotEmpty);
    // The documented fallback: keep the widget, let the engine skip the work.
    expect(filters.every((BackdropFilter f) => f.enabled), isFalse);
    expect(tester.takeException(), isNull);

    // And back on again.
    await tester.tap(find.byTooltip('Turn blur on'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .every((BackdropFilter f) => f.enabled),
      isTrue,
    );
  });

  testWidgets('sheet renders a glass header over an opaque body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showGlassSheet<void>(
                context: context,
                title: 'Filters',
                body: const SizedBox(
                  height: 200,
                  child: Center(child: Text('body')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('segmented control sits on one pane, not one per segment', (
    WidgetTester tester,
  ) async {
    Set<int> selected = <int>{0};

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Center(
                child: GlassSegmentedControl<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text('Day')),
                    ButtonSegment<int>(value: 1, label: Text('Week')),
                    ButtonSegment<int>(value: 2, label: Text('Month')),
                  ],
                  selected: selected,
                  onSelectionChanged: (Set<int> next) =>
                      setState(() => selected = next),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Week'), findsOneWidget);
    // Three segments, one BackdropFilter. That is the point of the example.
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(selected, <int>{2});
    expect(tester.takeException(), isNull);
  });

  testWidgets('fab dock renders and the primary action fires', (
    WidgetTester tester,
  ) async {
    int taps = 0;

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Center(
            child: GlassFabDock(
              onPrimaryAction: () => taps++,
              secondaryAction: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass group really shares one backdrop key', (
    WidgetTester tester,
  ) async {
    const Widget pair = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(width: 200, height: 60, child: GlassSurface()),
        SizedBox(height: 8),
        SizedBox(width: 200, height: 60, child: GlassSurface()),
      ],
    );

    Future<Set<BackdropKey?>> keysFor(Widget child) async {
      await tester.pumpWidget(_host(Scaffold(body: Center(child: child))));
      await tester.pumpAndSettle();
      return tester
          .renderObjectList<RenderBackdropFilter>(
            find.byType(BackdropFilter),
          )
          .map((RenderBackdropFilter r) => r.backdropKey)
          .toSet();
    }

    final Set<BackdropKey?> grouped = await keysFor(
      const GlassGroup(child: pair),
    );
    // One shared, non-null key: the engine can perform the filtering once.
    expect(grouped.length, 1);
    expect(grouped.single, isNotNull);

    // Control: without a group the same two filters get no key at all, so the
    // assertion above cannot pass vacuously.
    final Set<BackdropKey?> ungrouped = await keysFor(pair);
    expect(ungrouped, <BackdropKey?>{null});

    expect(tester.takeException(), isNull);
  });
}
