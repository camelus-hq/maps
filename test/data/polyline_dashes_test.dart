import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/polyline_dashes.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';

void main() {
  test('splits a straight walk into alternating dashes and gaps', () {
    // ~1000 m due north-ish; each degree of latitude is ~111 km.
    final List<LatLon> walk = <LatLon>[
      const LatLon(52.5, 13.4),
      const LatLon(52.509, 13.4),
    ];
    final List<List<LatLon>> segments = dashPolyline(
      walk,
      dashMeters: 25,
      gapMeters: 25,
    );

    expect(segments.length, greaterThan(4));
    // Drawn length is roughly half the path (dash and gap are equal).
    final double drawn = dashSegmentsLength(segments);
    final double total = walk.first.distanceTo(walk.last);
    expect(drawn, lessThan(total));
    expect(drawn, greaterThan(total * 0.4));
    // Every drawn piece has at least two points and no piece is longer than a
    // dash (plus a little tolerance).
    for (final List<LatLon> segment in segments) {
      expect(segment.length, greaterThanOrEqualTo(2));
      expect(dashSegmentsLength(<List<LatLon>>[segment]), lessThan(30));
    }
  });

  test('a two-point walk yields dashes that start and end on the line', () {
    const LatLon a = LatLon(52.5, 13.4);
    const LatLon b = LatLon(52.501, 13.4);
    final List<List<LatLon>> segments = dashPolyline(<LatLon>[a, b]);
    expect(segments, isNotEmpty);
    expect(segments.first.first, a);
  });

  test('caps the number of segments for a very long walk', () {
    final List<LatLon> longWalk = <LatLon>[
      for (int i = 0; i <= 100; i++) LatLon(52.0 + i * 0.01, 13.4),
    ];
    final List<List<LatLon>> segments = dashPolyline(longWalk, maxSegments: 20);
    expect(segments, hasLength(20));
  });

  test('hostile input returns an empty list (never throws)', () {
    for (final List<LatLon> points in <List<LatLon>>[
      <LatLon>[],
      <LatLon>[const LatLon(1, 2)],
      <LatLon>[const LatLon(1, 2), const LatLon(1, 2)], // zero length
    ]) {
      expect(
        () => dashPolyline(points),
        returnsNormally,
        reason: 'points: $points',
      );
    }
    expect(dashPolyline(const <LatLon>[]), isEmpty);
    expect(dashPolyline(const <LatLon>[LatLon(1, 2)]), isEmpty);
    // Non-positive dash/gap values are clamped, not crashed.
    expect(
      () => dashPolyline(
        const <LatLon>[LatLon(1, 2), LatLon(1.01, 2)],
        dashMeters: 0,
        gapMeters: -3,
      ),
      returnsNormally,
    );
  });
}
