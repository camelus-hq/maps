import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../state/map_viewport.dart';

/// Invisible layer that reports the map viewport size to [mapViewportProvider].
///
/// It has no visual of its own: search uses the measured size (with the live
/// camera) to bound a POI category query to what is on screen. Returning a
/// transparent box means it never steals a gesture from the map.
class MapViewportLayer extends ConsumerWidget {
  const MapViewportLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(constraints.maxWidth, constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          ref.read(mapViewportProvider.notifier).report(viewport);
        });
        return const SizedBox.shrink();
      },
    );
  }
}
