import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/mapbox_geocoding_mapper.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';

void main() {
  group('MapboxGeocodingMapper.fromFeature', () {
    test('maps a well-formed feature', () {
      final Place? place = MapboxGeocodingMapper.fromFeature(<String, Object?>{
        'id': 'poi.123',
        'text': 'Harbour Coffee',
        'place_name': 'Harbour Coffee, 1 Lantern Way, Berlin',
        'center': <Object?>[13.4075, 52.5210],
        'properties': <String, Object?>{'category': 'cafe'},
      });
      expect(place?.name, 'Harbour Coffee');
      expect(place?.position, const LatLon(52.5210, 13.4075));
      expect(place?.category, 'cafe');
      expect(place?.address, 'Harbour Coffee, 1 Lantern Way, Berlin');
    });

    test('falls back to place_name and the categories list', () {
      final Place? place = MapboxGeocodingMapper.fromFeature(<String, Object?>{
        'id': 'b',
        'place_name': 'Somewhere',
        'center': <Object?>[13.4, 52.5],
        'properties': <String, Object?>{
          'categories': <Object?>['restaurant', 'food'],
        },
      });
      expect(place?.name, 'Somewhere');
      expect(place?.category, 'restaurant');
    });
  });
}
