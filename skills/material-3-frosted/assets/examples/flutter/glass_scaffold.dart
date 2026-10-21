// Flutter — glass chrome over scrolling content.
//
// The topology is the whole trick:
//
//   Stack
//   ├── scrollable content        (painted first — this is the backdrop)
//   ├── glass app bar             (paints over it, blurred)
//   └── glass navigation bar      (Scaffold's bottomNavigationBar, body extends behind)
//
// A `BackdropFilter` can only filter what was already painted. Put the glass in
// the Scaffold's `appBar` slot and, depending on how the body lays out, you may
// be filtering an empty region and see nothing at all. Painting the content
// first and the chrome after it removes the guesswork.
//
// Two more decisions worth naming:
//
// - The app bar is transparent until the content scrolls under it. A bar that
//   is frosted at rest looks like a mistake; it is a *scroll affordance*.
// - Content cards are opaque Material surfaces. Glass is chrome (Tier 1);
//   paragraphs and list rows are Tier 3 and never get it. Flutter makes it very
//   easy to forget this because `BackdropFilter` is a one-line wrapper.

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_theme.dart';

class GlassScaffold extends StatefulWidget {
  const GlassScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.body,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.appBarActions,
    this.onBlurToggle,
  });

  final String title;
  final List<NavigationDestination> destinations;
  final Widget body;

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  final List<Widget>? appBarActions;

  /// Passed through to the scope's switch so a settings screen can own it.
  final ValueChanged<bool>? onBlurToggle;

  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold> {
  bool _scrolled = false;

  bool _handleScroll(ScrollNotification notification) {
    // Only the offset matters, and only its sign: this is an affordance, not a
    // parallax effect. Reading it in a notification avoids rebuilding on every
    // pixel of scroll.
    final bool scrolled = notification.metrics.pixels > 4;
    if (scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final FrostedGlassScope scope = FrostedGlassScope.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool animationsOff = MediaQuery.disableAnimationsOf(context);

    return GlassGroup(
      child: Scaffold(
        // The body runs under the navigation bar; the bar's glass samples it.
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: Stack(
            children: <Widget>[
              // 1. Content. Padded, not shrunk: the first item must be
              //    reachable and the last one must clear the navigation bar.
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      kBottomNavigationBarHeight,
                ),
                child: widget.body,
              ),

              // 2. App bar. Opaque chrome the user reads, glass only as the
              //    scroll affordance.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _scrolled ? 1 : 0,
                  duration: animationsOff
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: SafeArea(
                    bottom: false,
                    child: GlassBar(
                      height: kToolbarHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  widget.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            ...?widget.appBarActions,
                            if (scope.onBlurEnabledChanged != null)
                              IconButton(
                                tooltip: scope.blurEnabled
                                    ? 'Turn blur off'
                                    : 'Turn blur on',
                                icon: Icon(
                                  scope.blurEnabled
                                      ? Icons.blur_on_outlined
                                      : Icons.blur_off_outlined,
                                ),
                                onPressed: () => scope.onBlurEnabledChanged!(
                                  !scope.blurEnabled,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Navigation bar. Top-level destinations only — this is the one
        //    place where a translucent bar is unambiguous.
        bottomNavigationBar: GlassBar(
          style: GlassStyle.chrome(scheme),
          child: NavigationBar(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            destinations: widget.destinations,
          ),
        ),
      ),
    );
  }
}
