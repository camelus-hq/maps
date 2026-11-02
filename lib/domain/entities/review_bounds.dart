import 'camera.dart';
import 'lat_lon.dart';
import 'lat_lon_bounds.dart';

/// A visible map rectangle, used to ask for only the reviews on screen.
///
/// The map/review state computes it from the camera and the viewport size (a
/// Web-Mercator approximation is plenty for "what is roughly on screen"), and
/// the data layer turns it into a small set of geohash prefixes to query.
class ReviewBounds {
  const ReviewBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  double get latSpan => (north - south).abs();

  double get lonSpan => (east - west).abs();

  LatLon get center => LatLon((north + south) / 2, (west + east) / 2);

  /// Whether [point] falls inside the rectangle. The edges are inclusive and a
  /// margin can be added so a review sitting just off-screen (its pin still
  /// visible) is not dropped.
  bool contains(LatLon point, {double marginDegrees = 0}) {
    return point.latitude >= south - marginDegrees &&
        point.latitude <= north + marginDegrees &&
        point.longitude >= west - marginDegrees &&
        point.longitude <= east + marginDegrees;
  }

  /// The visible rectangle for [camera] over a viewport of
  /// `widthPx × heightPx` logical pixels.
  ///
  /// Delegates to [LatLonBounds.fromCamera] (the same slippy-map maths) so the
  /// review cover and the POI-search box can never drift.
  static ReviewBounds fromCamera(
    Camera camera, {
    required double widthPx,
    required double heightPx,
  }) {
    final LatLonBounds bounds = LatLonBounds.fromCamera(
      camera,
      widthPx: widthPx,
      heightPx: heightPx,
    );
    return ReviewBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
    );
  }

  @override
  String toString() => 'ReviewBounds(n:$north, s:$south, e:$east, w:$west)';
}
