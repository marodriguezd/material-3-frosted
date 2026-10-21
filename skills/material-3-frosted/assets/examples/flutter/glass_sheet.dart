// Flutter — a modal sheet whose header is glass and whose body is not.
//
// This is the one place where the glass is genuinely useful in a sheet: it
// creates depth between the sheet and the page it covers, and the drag handle
// sits on something that reads as a surface rather than a floating pill.
//
// The body stays opaque. A full-height glass sheet is the classic failure: the
// text over it moves, contrast changes as you scroll the page behind, and
// reading becomes work.
//
// Two Flutter specifics:
//
// - `backgroundColor: Colors.transparent` is mandatory. The default
//   `BottomSheet` paints its own Material first, and your backdrop filter then
//   blurs that flat colour instead of the page — the sheet looks like a
//   slightly greyer solid, and nothing warns you.
// - The sheet is painted in an overlay above the route, so the backdrop it
//   samples is the page *plus* the modal barrier. Dimming happens before the
//   blur, which is what you want: blurring an undimmed page makes the sheet
//   look like it is floating in the content.

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_theme.dart';

/// Shows a sheet with a frosted header.
///
/// Returns whatever the user picked, or `null`. `isScrollControlled` is on so
/// the sheet can exceed half the screen when the content is a long list —
/// without it, tall sheets clip and the scroll view fights the drag gesture.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  Widget? leading,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheetContext) {
      return GlassSheet(title: title, leading: leading, child: body);
    },
  );
}

class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.maxHeightFactor = 0.85,
  });

  final String title;
  final Widget child;
  final Widget? leading;

  /// Fraction of the screen the sheet may occupy. A sheet that can reach the
  /// top edge stops reading as a sheet.
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Glass header: handle + title, over the dimmed page.
          GlassSurface(
            radius: 28,
            style: GlassStyle.chrome(scheme),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: <Widget>[
                      if (leading != null) ...<Widget>[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          // Opaque body. This is where the user reads and taps.
          Flexible(
            child: ColoredBox(
              color: scheme.surfaceContainerLow,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
