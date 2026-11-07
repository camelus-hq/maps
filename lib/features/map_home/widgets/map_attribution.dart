import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/ports.dart';
import '../../../state/sheet_anchor.dart';

/// The map's data attribution, drawn by us.
///
/// Mapbox's native attribution ornament is disabled in [MapboxMapService]
/// because it sits glued to the bottom-left of the platform view, underneath
/// the sheet (Android draws the logo and the attribution in the same corner).
/// This widget replaces it: the same [sheetAnchorProvider]-driven behaviour as
/// [MapControls] — attached to the sheet's top edge and fading out once the
/// sheet is tall enough ([SheetAnchor.hidesChrome]).
///
/// Keeping the credit in our own widget is deliberate: swapping it for a link
/// to the About/attribution screen, or replacing Mapbox with another renderer,
/// is a change to this one file.
class MapAttribution extends ConsumerWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SheetAnchor? anchor = ref.watch(sheetAnchorProvider);
    final bool hidden = anchor == null || anchor.hidesChrome;

    return Positioned(
      left: AppSpacing.md,
      bottom: (anchor ?? SheetAnchor.none).topInset + AppSpacing.xs,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: const _AttributionCredit(),
        ),
      ),
    );
  }
}

/// The attribution links, on a translucent chip so they stay readable over
/// any map style.
class _AttributionCredit extends ConsumerWidget {
  const _AttributionCredit();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle? linkStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('© '),
            _AttributionLink(
              label: 'Mapbox',
              style: linkStyle,
              onTap: () => ref
                  .read(externalActionsProvider)
                  .openWebsite('https://www.mapbox.com/about/maps'),
            ),
            Text(' © '),
            _AttributionLink(
              label: 'OpenStreetMap',
              style: linkStyle,
              onTap: () => ref
                  .read(externalActionsProvider)
                  .openWebsite('http://www.openstreetmap.org/about/'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle? style;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await onTap();
      },
      child: Semantics(
        link: true,
        label: label,
        child: Text(label, style: style),
      ),
    );
  }
}
