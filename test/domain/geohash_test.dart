import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/geohash.dart';

/// The geohash helpers are the spatial index behind map review queries, so
/// correct encoding, prefix nesting and viewport covering are load-bearing.
void main() {
  group('encode', () {
    test('matches the canonical geohash example', () {
      expect(Geohash.encode(42.6, -5.6, precision: 5), 'ezs42');
    });

    test('clamps precision into 1..12', () {
      expect(Geohash.encode(52.52, 13.405, precision: 0).length, 1);
      expect(Geohash.encode(52.52, 13.405, precision: 99).length, 12);
    });

    test('tryEncode rejects out-of-range and non-finite input', () {
      expect(Geohash.tryEncode(91, 0), isNull);
      expect(Geohash.tryEncode(0, 181), isNull);
      expect(Geohash.tryEncode(double.nan, 0), isNull);
      expect(Geohash.tryEncode(null, null), isNull);
      expect(Geohash.tryEncode('52.52', '13.405'), isNotNull);
    });
  });

  group('decode', () {
    test('round-trips a point within the cell precision', () {
      final String hash = Geohash.encode(52.5195, 13.4120, precision: 9);
      final GeoCenter? center = Geohash.tryDecode(hash);
      expect(center, isNotNull);
      expect(center!.latitude, closeTo(52.5195, 0.0001));
      expect(center.longitude, closeTo(13.4120, 0.0001));
    });

    test('rejects anything that is not a geohash', () {
      expect(Geohash.tryDecode(''), isNull);
      expect(Geohash.tryDecode('abc !'), isNull);
      expect(Geohash.tryDecode('a' * 20), isNull);
      expect(Geohash.tryDecode('u33dbtq4w' * 2), isNull);
    });
  });

  group('prefixes', () {
    test('lists the full hash then one character shorter each time', () {
      expect(Geohash.prefixes('u33dbtq4w'), <String>[
        'u33dbtq4w',
        'u33dbtq4',
        'u33dbtq',
        'u33dbt',
        'u33db',
        'u33d',
        'u33',
        'u3',
        'u',
      ]);
    });

    test('honours the minimum precision', () {
      expect(Geohash.prefixes('u33dbtq4w', minPrecision: 6), <String>[
        'u33dbtq4w',
        'u33dbtq4',
        'u33dbtq',
        'u33dbt',
      ]);
    });

    test('empty input yields nothing', () {
      expect(Geohash.prefixes(''), isEmpty);
    });
  });

  group('cover', () {
    test('every cell contains a point inside the rectangle', () {
      const double north = 52.53, south = 52.51, east = 13.42, west = 13.39;
      final List<String> cells = Geohash.cover(
        north: north,
        south: south,
        east: east,
        west: west,
        precision: 6,
      );
      expect(cells, isNotEmpty);
      for (final String cell in cells) {
        expect(cell.length, 6);
      }
      // A review inside the rectangle must fall under one of the cells.
      final String inside = Geohash.encode(52.52, 13.405, precision: 6);
      expect(cells, contains(inside));
    });

    test('caps the number of sampled cells', () {
      final List<String> cells = Geohash.cover(
        north: 80,
        south: -80,
        east: 179,
        west: -179,
        precision: 9,
        maxCells: 4,
      );
      // (maxCells + 1) squared worst case.
      expect(cells.length, lessThanOrEqualTo(25));
    });

    test('handles an inverted rectangle without throwing', () {
      final List<String> cells = Geohash.cover(
        north: 52.51,
        south: 52.53,
        east: 13.39,
        west: 13.42,
        precision: 5,
      );
      expect(cells, isNotEmpty);
    });
  });
}
