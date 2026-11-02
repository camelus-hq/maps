import 'lat_lon.dart';

/// A styled polyline drawn on the map.
///
/// One [RouteLine] per drawn segment lets a public-transport journey carry the
/// operator's colour on each ride and a dashed line on the walking legs, while a
/// street route keeps a single highlighted line.
class RouteLine {
  const RouteLine({
    required this.points,
    this.color,
    this.dashed = false,
    this.width = 5,
  });

  /// Ordered polyline vertices (at least two to be drawn).
  final List<LatLon> points;

  /// Line colour as ARGB; `null` lets the adapter pick its default route colour.
  final int? color;

  /// Whether the line is drawn dashed (used for walking legs).
  final bool dashed;

  /// Line width in logical pixels.
  final double width;

  bool get isDrawable => points.length >= 2;
}
