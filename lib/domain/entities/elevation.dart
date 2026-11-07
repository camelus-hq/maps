import 'dart:math' as math;

/// A sampled elevation along a route: metres above sea level at a cumulative
/// distance from the start.
class ElevationPoint {
  const ElevationPoint({
    required this.distanceMeters,
    required this.elevationMeters,
  });

  final double distanceMeters;
  final double elevationMeters;
}

/// The elevation profile of a route (ascending distance order).
///
/// A profile with fewer than two finite points is treated as [isEmpty]: the
/// routing provider either has no elevation dataset for the area (Valhalla
/// returns `null` heights) or the sample failed. Callers must tolerate that —
/// the cycling UI simply omits the gradient page.
class ElevationProfile {
  const ElevationProfile(this.points);

  static const ElevationProfile empty = ElevationProfile(<ElevationPoint>[]);

  final List<ElevationPoint> points;

  bool get isUsable => points.length >= 2;

  bool get isEmpty => !isUsable;

  bool get isNotEmpty => isUsable;

  /// The highest sampled point (metres), or 0 when empty.
  double get maxElevation {
    if (points.isEmpty) {
      return 0;
    }
    double max = points.first.elevationMeters;
    for (final ElevationPoint point in points) {
      max = math.max(max, point.elevationMeters);
    }
    return max;
  }

  /// The lowest sampled point (metres), or 0 when empty.
  double get minElevation {
    if (points.isEmpty) {
      return 0;
    }
    double min = points.first.elevationMeters;
    for (final ElevationPoint point in points) {
      min = math.min(min, point.elevationMeters);
    }
    return min;
  }

  /// Total metres climbed (sum of the positive deltas).
  double get ascent {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      final double delta =
          points[i].elevationMeters - points[i - 1].elevationMeters;
      if (delta > 0) {
        total += delta;
      }
    }
    return total;
  }

  /// Total metres descended (sum of the absolute negative deltas).
  double get descent {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      final double delta =
          points[i - 1].elevationMeters - points[i].elevationMeters;
      if (delta > 0) {
        total += delta;
      }
    }
    return total;
  }

  /// The interpolated elevation at [distance] (clamped to the profile).
  double elevationAt(double distance) {
    if (points.isEmpty) {
      return 0;
    }
    if (distance <= points.first.distanceMeters) {
      return points.first.elevationMeters;
    }
    for (int i = 1; i < points.length; i++) {
      final ElevationPoint previous = points[i - 1];
      final ElevationPoint next = points[i];
      if (distance <= next.distanceMeters) {
        final double span = next.distanceMeters - previous.distanceMeters;
        final double t = span <= 0
            ? 0
            : ((distance - previous.distanceMeters) / span).clamp(0.0, 1.0);
        return previous.elevationMeters +
            (next.elevationMeters - previous.elevationMeters) * t;
      }
    }
    return points.last.elevationMeters;
  }

  /// The local grade in percent around [distance], measured across a window of
  /// [windowMeters] on either side (a wider window smooths GPS/terrain noise).
  double gradeAt(double distance, {double windowMeters = 80}) {
    if (!isUsable) {
      return 0;
    }
    final double from = distance - windowMeters;
    final double to = distance + windowMeters;
    final double rise = elevationAt(to) - elevationAt(from);
    final double run = to - from;
    if (run <= 0) {
      return 0;
    }
    return (rise / run) * 100;
  }

  /// The steepest signed grade (percent) between [distance] and
  /// [distance] + [aheadMeters]. Positive means climbing.
  double maxGradeAhead(double distance, {double aheadMeters = 250}) {
    if (!isUsable || aheadMeters <= 0) {
      return 0;
    }
    final double step = (aheadMeters / 8).clamp(10.0, 100.0);
    double steepest = 0;
    for (double d = distance; d <= distance + aheadMeters; d += step) {
      final double grade = gradeAt(d, windowMeters: step);
      if (grade.abs() > steepest.abs()) {
        steepest = grade;
      }
    }
    return steepest;
  }
}
