import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/mapbox_search_box_mapper.dart';
import 'package:openmaps/domain/entities/place.dart';

void main() {
  test('maps a properties.coordinates Search Box feature', () {
    final Place? place = MapboxSearchBoxMapper.fromFeature(<String, Object?>{
      'type': 'Feature',
      'properties': <String, Object?>{
        'name': 'Café X',
        'mapbox_id': 'poi.1',
        'feature_type': 'poi',
        'full_address': 'Street 1, Berlin',
        'poi_category': <Object?>['cafe', 'coffee'],
        'coordinates': <String, Object?>{'longitude': 13.4, 'latitude': 52.5},
      },
    });
    expect(place, isNotNull);
    expect(place!.id, 'poi.1');
    expect(place.name, 'Café X');
    expect(place.position.latitude, closeTo(52.5, 1e-9));
    expect(place.category, 'cafe');
    expect(place.address, 'Street 1, Berlin');
  });

  test('maps a geometry.coordinates Search Box feature', () {
    final Place? place = MapboxSearchBoxMapper.fromFeature(<String, Object?>{
      'type': 'Feature',
      'geometry': <String, Object?>{
        'type': 'Point',
        'coordinates': <Object?>[13.4, 52.5],
      },
      'properties': <String, Object?>{
        'name': 'Park Y',
        'mapbox_id': 'poi.2',
        'place_formatted': 'Berlin, Germany',
      },
    });
    expect(place, isNotNull);
    expect(place!.position.longitude, closeTo(13.4, 1e-9));
    expect(place.address, 'Berlin, Germany');
  });

  test('never throws on hostile features', () {
    final List<Object?> hostile = <Object?>[
      null,
      42,
      'x',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{'properties': 'x'},
      <String, Object?>{
        'properties': <String, Object?>{'name': 'x'},
      },
      <String, Object?>{
        'properties': <String, Object?>{'name': 'x', 'mapbox_id': 'a'},
      },
      <String, Object?>{
        'properties': <String, Object?>{
          'name': 'x',
          'mapbox_id': 'a',
          'coordinates': <String, Object?>{'latitude': 999, 'longitude': 1},
        },
      },
      <String, Object?>{
        'geometry': <String, Object?>{
          'coordinates': <Object?>[1],
        },
        'properties': <String, Object?>{'name': 'x', 'mapbox_id': 'a'},
      },
    ];
    for (final Object? feature in hostile) {
      expect(
        () => MapboxSearchBoxMapper.fromFeature(feature),
        returnsNormally,
        reason: 'feature: $feature',
      );
    }
  });
}
