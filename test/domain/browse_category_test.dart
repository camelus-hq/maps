import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/lat_lon_bounds.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/ports/search_service.dart';
import 'package:openmaps/domain/usecases/browse_category.dart';

/// Records the bounds it was asked to search.
class _RecordingSearch implements SearchService {
  LatLonBounds? lastBounds;

  @override
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async => const <Place>[];

  @override
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  }) async {
    lastBounds = bounds;
    return const <Place>[];
  }
}

void main() {
  group('BrowseCategory', () {
    test('caps the viewport bounds to a sub-kilometre box', () async {
      final _RecordingSearch search = _RecordingSearch();
      final BrowseCategory useCase = BrowseCategory(search);

      await useCase(
        'cafe',
        proximity: const LatLon(52.5, 13.5),
        bounds: const LatLonBounds(north: 53, south: 52, east: 14, west: 13),
      );

      final LatLonBounds? bounds = search.lastBounds;
      expect(bounds, isNotNull);
      expect(bounds!.center.latitude, closeTo(52.5, 1e-9));
      final double latSpanMeters = (bounds.north - bounds.south) * 111320;
      final double lonSpanMeters =
          (bounds.east - bounds.west) *
          111320 *
          math.cos(52.5 * math.pi / 180).abs();
      expect(latSpanMeters, lessThanOrEqualTo(1000 + 1));
      expect(lonSpanMeters, lessThanOrEqualTo(1000 + 1));
    });

    test('passes no bounds through when none were given', () async {
      final _RecordingSearch search = _RecordingSearch();
      await BrowseCategory(search)('cafe', proximity: const LatLon(52.5, 13.5));
      expect(search.lastBounds, isNull);
    });

    test('rejects an empty category', () async {
      final result = await BrowseCategory(_RecordingSearch())(
        ' ',
        proximity: const LatLon(52.5, 13.5),
      );
      expect(result.isErr, isTrue);
    });
  });
}
