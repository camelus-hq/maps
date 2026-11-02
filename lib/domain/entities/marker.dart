import 'lat_lon.dart';

/// A transient marker on the map (search result, saved place, picked point…).
class Marker {
  const Marker({
    required this.id,
    required this.position,
    this.selected = false,
  });

  final String id;
  final LatLon position;

  /// Whether this is the place currently open in the details sheet. The map
  /// draws it larger so it stands out from the other result pins.
  final bool selected;
}
