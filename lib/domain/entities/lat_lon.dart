import 'dart:math' as math;

/// A WGS84 coordinate in decimal degrees.
///
/// External coordinates must be built through [tryParse] so hostile payloads
/// cannot produce out-of-range or non-finite values.
class LatLon {
  const LatLon(this.latitude, this.longitude)
    : assert(latitude >= -90 && latitude <= 90, 'latitude out of range'),
      assert(longitude >= -180 && longitude <= 180, 'longitude out of range');

  final double latitude;
  final double longitude;

  /// Parses arbitrary input (numbers, numeric strings, nulls) into a
  /// coordinate, returning `null` for anything missing, non-finite or out of
  /// range.
  static LatLon? tryParse(Object? latitude, Object? longitude) {
    final double? lat = _toFiniteDouble(latitude);
    final double? lon = _toFiniteDouble(longitude);
    if (lat == null || lon == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return null;
    }
    return LatLon(lat, lon);
  }

  static double? _toFiniteDouble(Object? value) {
    final double? parsed = switch (value) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }

  /// Great-circle (haversine) distance to [other], in metres.
  double distanceTo(LatLon other) {
    const double earthRadiusMeters = 6378137;
    final double dLat = _toRadians(other.latitude - latitude);
    final double dLon = _toRadians(other.longitude - longitude);
    final double lat1 = _toRadians(latitude);
    final double lat2 = _toRadians(other.latitude);
    final double h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is LatLon &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLon($latitude, $longitude)';
}
