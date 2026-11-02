import 'dart:math' as math;

import 'camera.dart';
import 'lat_lon.dart';

/// An axis-aligned latitude/longitude rectangle.
///
/// Used to bound an *area* query — a POI category browse — to what is visible
/// on the map, so the data layer can ask for elements inside a bounding box
/// instead of a radius.
///
/// It is a plain value object; the Web-Mercator derivation from a [Camera] and
/// viewport size lives in [fromCamera]. (`ReviewBounds` is the review-specific
/// rectangle; it reuses this for its own camera maths.)
class LatLonBounds {
  const LatLonBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  /// Ceiling for a "near me" area search (a POI category browse): a viewport
  /// derived from a zoomed-out camera is capped to roughly a kilometre, so the
  /// query stays local whatever the map shows.
  static const double maxAreaSearchSpanMeters = 1000;

  final double north;
  final double south;
  final double east;
  final double west;

  LatLon get center => LatLon((north + south) / 2, (west + east) / 2);

  /// Whether [point] falls inside the rectangle (edges inclusive).
  bool contains(LatLon point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  /// The visible rectangle for [camera] over a viewport of
  /// `widthPx × heightPx` logical pixels.
  ///
  /// Uses the standard slippy-map metres-per-pixel formula. Rotated/tilted
  /// cameras are approximated by their axis-aligned footprint, which is what a
  /// spatial query wants anyway. Non-finite or non-positive viewport sizes fall
  /// back to a sensible portrait default.
  static LatLonBounds fromCamera(
    Camera camera, {
    required double widthPx,
    required double heightPx,
  }) {
    final double zoom = camera.zoom.clamp(0.0, 22.0);
    final double safeWidth = widthPx.isFinite && widthPx > 0 ? widthPx : 360;
    final double safeHeight = heightPx.isFinite && heightPx > 0
        ? heightPx
        : 640;
    final double lat = camera.target.latitude.clamp(-85.0, 85.0);
    final double latRadians = lat * math.pi / 180;
    final double metersPerPixel =
        156543.03392 * math.cos(latRadians) / math.pow(2, zoom).toDouble();
    final double halfHeightMeters = safeHeight / 2 * metersPerPixel;
    final double halfWidthMeters = safeWidth / 2 * metersPerPixel;
    final double deltaLat = halfHeightMeters / 111320;
    final double cosLat = math.cos(latRadians).abs();
    final double deltaLon =
        halfWidthMeters / (111320 * (cosLat < 0.01 ? 0.01 : cosLat));
    return LatLonBounds(
      north: (camera.target.latitude + deltaLat).clamp(-90.0, 90.0),
      south: (camera.target.latitude - deltaLat).clamp(-90.0, 90.0),
      east: camera.target.longitude + deltaLon,
      west: camera.target.longitude - deltaLon,
    );
  }

  /// This rectangle shrunk so neither side is longer than [maxSpanMeters],
  /// keeping it centred on [center].
  ///
  /// Lets a bound derived from a zoomed-out viewport be capped to a sane search
  /// area without moving off the middle of the screen.
  LatLonBounds cappedToMaxSpanMeters(double maxSpanMeters) {
    final double half = maxSpanMeters / 2;
    final LatLon middle = center;
    final double latRadians = middle.latitude * math.pi / 180;
    final double cosLat = math.cos(latRadians).abs();
    final double maxDeltaLat = half / 111320;
    final double maxDeltaLon =
        half / (111320 * (cosLat < 0.01 ? 0.01 : cosLat));
    return LatLonBounds(
      north: math.min(north, middle.latitude + maxDeltaLat),
      south: math.max(south, middle.latitude - maxDeltaLat),
      east: math.min(east, middle.longitude + maxDeltaLon),
      west: math.max(west, middle.longitude - maxDeltaLon),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LatLonBounds &&
      other.north == north &&
      other.south == south &&
      other.east == east &&
      other.west == west;

  @override
  int get hashCode => Object.hash(north, south, east, west);

  @override
  String toString() => 'LatLonBounds(n:$north, s:$south, e:$east, w:$west)';
}
