import '../../domain/entities/lat_lon.dart';

/// Splits a polyline into dash sub-polylines (draw ~[dashMeters], skip
/// ~[gapMeters]).
///
/// Mapbox's polyline annotations have no dash pattern, so a dashed line is drawn
/// as a run of short segments along the same path. Pure and bounded: a very long
/// walk can never create an unbounded number of segments, and hostile input
/// (fewer than two points) yields an empty list rather than throwing.
List<List<LatLon>> dashPolyline(
  List<LatLon> points, {
  double dashMeters = 25,
  double gapMeters = 18,
  int maxSegments = 400,
}) {
  if (points.length < 2 || maxSegments < 1) {
    return const <List<LatLon>>[];
  }
  final double dash = dashMeters > 0 ? dashMeters : 1;
  final double gap = gapMeters > 0 ? gapMeters : 1;
  final List<List<LatLon>> segments = <List<LatLon>>[];
  List<LatLon> current = <LatLon>[points.first];
  bool drawing = true;
  double remaining = dash;
  for (int i = 1; i < points.length; i++) {
    LatLon from = points[i - 1];
    final LatLon to = points[i];
    double segment = from.distanceTo(to);
    // Guard against a degenerate (zero-length) or non-finite hop.
    if (!segment.isFinite || segment <= 0) {
      if (drawing) {
        current.add(to);
      }
      continue;
    }
    while (segment > 0) {
      final double step = remaining < segment ? remaining : segment;
      final double t = step / segment;
      final LatLon next = LatLon(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      if (drawing) {
        current.add(next);
      }
      from = next;
      segment -= step;
      remaining -= step;
      if (remaining <= 1e-6) {
        if (drawing && current.length >= 2) {
          segments.add(current);
          if (segments.length >= maxSegments) {
            return segments;
          }
        }
        drawing = !drawing;
        remaining = drawing ? dash : gap;
        current = <LatLon>[from];
      }
    }
  }
  if (drawing && current.length >= 2 && segments.length < maxSegments) {
    segments.add(current);
  }
  return segments;
}

/// Total drawn length of [segments] in metres (used by tests).
double dashSegmentsLength(List<List<LatLon>> segments) {
  double total = 0;
  for (final List<LatLon> segment in segments) {
    for (int i = 1; i < segment.length; i++) {
      total += segment[i - 1].distanceTo(segment[i]);
    }
  }
  return total;
}
