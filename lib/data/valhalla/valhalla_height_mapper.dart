import '../../domain/entities/elevation.dart';

/// Lenient mapper from a Valhalla `/height` response to an [ElevationProfile].
///
/// The response carries `range_height`: a list of `[distance, height]` pairs.
/// Null heights (the provider has no elevation dataset for the area), malformed
/// entries, non-finite values and out-of-order distances are dropped; a profile
/// with fewer than two usable points degrades to [ElevationProfile.empty].
abstract final class ValhallaHeightMapper {
  /// A hostile payload cannot allocate more than this many samples.
  static const int _maxPoints = 4000;

  static ElevationProfile fromResponse(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return ElevationProfile.empty;
    }
    final Object? range = raw['range_height'];
    if (range is! List<Object?>) {
      return ElevationProfile.empty;
    }
    final List<ElevationPoint> points = <ElevationPoint>[];
    double lastDistance = double.negativeInfinity;
    for (final Object? entry in range) {
      if (points.length >= _maxPoints) {
        break;
      }
      if (entry is! List<Object?> || entry.length < 2) {
        continue;
      }
      final double? distance = _asDouble(entry[0]);
      final double? height = _asDouble(entry[1]);
      if (distance == null || height == null) {
        continue;
      }
      if (!distance.isFinite || !height.isFinite || distance < lastDistance) {
        continue;
      }
      points.add(
        ElevationPoint(distanceMeters: distance, elevationMeters: height),
      );
      lastDistance = distance;
    }
    if (points.length < 2) {
      return ElevationProfile.empty;
    }
    return ElevationProfile(List<ElevationPoint>.unmodifiable(points));
  }

  static double? _asDouble(Object? value) => switch (value) {
    final double value => value,
    final int value => value.toDouble(),
    _ => null,
  };
}
