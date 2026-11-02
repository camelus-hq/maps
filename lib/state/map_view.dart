import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the widget that renders the map viewport.
///
/// The default is a blank box; `lib/app/di.dart` overrides it with the Mapbox
/// surface when a token is configured. Keeping the seam here lets the feature
/// layer stay free of Mapbox types.
typedef MapViewBuilder = Widget Function(BuildContext context);

final Provider<MapViewBuilder> mapViewBuilderProvider =
    Provider<MapViewBuilder>(
      (Ref ref) =>
          (BuildContext context) => const SizedBox.shrink(),
    );
