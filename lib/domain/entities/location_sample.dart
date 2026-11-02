import 'lat_lon.dart';

/// One position sample from the location service.
class LocationSample {
  const LocationSample({
    required this.position,
    this.bearing,
    this.speedMetersPerSecond,
    this.accuracyMeters,
  });

  final LatLon position;

  /// Degrees clockwise from north, or `null` when stationary/unknown.
  final double? bearing;
  final double? speedMetersPerSecond;
  final double? accuracyMeters;
}
