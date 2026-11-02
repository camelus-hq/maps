import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/lat_lon_bounds.dart';

void main() {
  group('LatLonBounds', () {
    test('fromCamera derives the visible rectangle around the target', () {
      final LatLonBounds bounds = LatLonBounds.fromCamera(
        const Camera(target: LatLon(52.52, 13.405), zoom: 14),
        widthPx: 400,
        heightPx: 800,
      );

      // Portrait viewport: taller than wide, so the latitude span wins.
      expect(bounds.center.latitude, closeTo(52.52, 1e-6));
      expect(bounds.center.longitude, closeTo(13.405, 1e-6));
      expect(
        bounds.north - bounds.south,
        greaterThan(bounds.east - bounds.west),
      );
      expect(bounds.north, closeTo(52.5409, 1e-3));
      expect(bounds.south, closeTo(52.4991, 1e-3));
    });

    test('a wider zoom gives a wider box', () {
      LatLonBounds at(double zoom) => LatLonBounds.fromCamera(
        Camera(target: const LatLon(52.52, 13.405), zoom: zoom),
        widthPx: 400,
        heightPx: 800,
      );
      expect(
        at(12).north - at(12).south,
        greaterThan(at(16).north - at(16).south),
      );
    });

    test('fromCamera tolerates a degenerate viewport', () {
      final LatLonBounds bounds = LatLonBounds.fromCamera(
        const Camera(target: LatLon(52.52, 13.405)),
        widthPx: double.nan,
        heightPx: 0,
      );
      expect(bounds.north.isFinite, isTrue);
      expect(bounds.east.isFinite, isTrue);
      expect(bounds.north, greaterThan(bounds.south));
    });

    test('cappedToMaxSpanMeters shrinks a large box around its centre', () {
      const LatLonBounds huge = LatLonBounds(
        north: 53,
        south: 52,
        east: 14,
        west: 13,
      );
      final LatLonBounds capped = huge.cappedToMaxSpanMeters(1000);

      expect(capped.center.latitude, closeTo(52.5, 1e-9));
      expect(capped.center.longitude, closeTo(13.5, 1e-9));
      final double latSpanMeters = (capped.north - capped.south) * 111320;
      final double lonSpanMeters =
          (capped.east - capped.west) *
          111320 *
          math.cos(52.5 * math.pi / 180).abs();
      expect(latSpanMeters, lessThanOrEqualTo(1000 + 1));
      expect(lonSpanMeters, lessThanOrEqualTo(1000 + 1));
    });

    test('cappedToMaxSpanMeters leaves a small box alone', () {
      const LatLonBounds small = LatLonBounds(
        north: 52.521,
        south: 52.519,
        east: 13.406,
        west: 13.404,
      );
      expect(small.cappedToMaxSpanMeters(1000), small);
    });

    test('contains is edge-inclusive', () {
      const LatLonBounds bounds = LatLonBounds(
        north: 52.53,
        south: 52.51,
        east: 13.42,
        west: 13.39,
      );
      expect(bounds.contains(const LatLon(52.52, 13.405)), isTrue);
      expect(bounds.contains(const LatLon(52.51, 13.39)), isTrue);
      expect(bounds.contains(const LatLon(52.54, 13.405)), isFalse);
      expect(bounds.contains(const LatLon(52.52, 13.43)), isFalse);
    });
  });
}
