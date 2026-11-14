import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../state/config.dart';
import '../../../state/map_view.dart';
import 'map_surface_placeholder.dart';

/// The map viewport.
///
/// Renders the real Mapbox surface when a token is configured, otherwise a
/// keyless placeholder so the app always runs.
class MapSurface extends ConsumerWidget {
  const MapSurface({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).hasMapboxToken) {
      return const MapSurfacePlaceholder();
    }
    final MapViewBuilder builder = ref.watch(mapViewBuilderProvider);
    return builder(context);
  }
}
