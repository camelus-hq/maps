import 'lat_lon.dart';

/// The map camera pose.
class Camera {
  const Camera({
    required this.target,
    this.zoom = 12,
    this.bearing = 0,
    this.tilt = 0,
  });

  final LatLon target;
  final double zoom;

  /// Degrees clockwise from north.
  final double bearing;

  /// Degrees from vertical.
  final double tilt;

  Camera copyWith({
    LatLon? target,
    double? zoom,
    double? bearing,
    double? tilt,
  }) => Camera(
    target: target ?? this.target,
    zoom: zoom ?? this.zoom,
    bearing: bearing ?? this.bearing,
    tilt: tilt ?? this.tilt,
  );

  @override
  String toString() =>
      'Camera(target: $target, zoom: $zoom, bearing: $bearing, tilt: $tilt)';
}
