import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Stand-in for the map surface until the Mapbox adapter lands (M2).
///
/// Intentionally plain: no Google look, no map imagery.
class MapSurfacePlaceholder extends StatelessWidget {
  const MapSurfacePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color background = brightness == Brightness.dark
        ? AppColors.mapPlaceholderDark
        : AppColors.mapPlaceholder;
    return ColoredBox(
      color: background,
      child: const Center(child: Text('Map surface (Mapbox lands in M2)')),
    );
  }
}
