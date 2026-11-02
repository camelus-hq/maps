import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';

void main() {
  group('LatLon.tryParse', () {
    test('accepts numeric and numeric-string input', () {
      expect(LatLon.tryParse(52.5, 13.4), const LatLon(52.5, 13.4));
      expect(LatLon.tryParse('52.5', '13.4'), const LatLon(52.5, 13.4));
      expect(LatLon.tryParse(52, 13), const LatLon(52, 13));
    });

    test('rejects hostile payloads', () {
      expect(LatLon.tryParse(null, 13.4), isNull);
      expect(LatLon.tryParse(52.5, null), isNull);
      expect(LatLon.tryParse('not-a-number', 13.4), isNull);
      expect(LatLon.tryParse(double.nan, 13.4), isNull);
      expect(LatLon.tryParse(double.infinity, 13.4), isNull);
      expect(LatLon.tryParse(91, 13.4), isNull);
      expect(LatLon.tryParse(52.5, 181), isNull);
      expect(LatLon.tryParse(<String, dynamic>{}, 13.4), isNull);
    });
  });

  test('distanceTo measures a known segment', () {
    // One degree of latitude is ~111.2 km.
    final double distance = const LatLon(0, 0).distanceTo(const LatLon(1, 0));
    expect(distance, closeTo(111195, 500));
  });
}
