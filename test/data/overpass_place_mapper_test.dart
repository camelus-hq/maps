import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/overpass_place_mapper.dart';
import 'package:openmaps/domain/entities/place.dart';

void main() {
  group('OverpassPlaceMapper', () {
    test('maps a named node with an OSM reference id and address', () {
      final Place? place = OverpassPlaceMapper.fromElement(<String, Object?>{
        'type': 'node',
        'id': 2764050762,
        'lat': 52.52,
        'lon': 13.405,
        'tags': <String, Object?>{
          'name': 'Café X',
          'amenity': 'cafe',
          'addr:street': 'Grunerstraße',
          'addr:housenumber': '7',
          'addr:postcode': '10179',
          'addr:city': 'Berlin',
        },
      });

      expect(place, isNotNull);
      expect(place!.id, 'node/2764050762');
      expect(place.name, 'Café X');
      expect(place.category, 'cafe');
      expect(place.address, '7 Grunerstraße, 10179 Berlin');
    });

    test('reads the center of a way and a relation', () {
      Place? from(String type) =>
          OverpassPlaceMapper.fromElement(<String, Object?>{
            'type': type,
            'id': 5,
            'center': <String, Object?>{'lat': 52.5, 'lon': 13.4},
            'tags': <String, Object?>{'name': 'Park', 'leisure': 'park'},
          });
      expect(from('way')!.id, 'way/5');
      expect(from('way')!.position.latitude, 52.5);
      expect(from('relation')!.id, 'relation/5');
    });

    test('humanises the category as a name for an unnamed element', () {
      final Place? place = OverpassPlaceMapper.fromElement(<String, Object?>{
        'type': 'node',
        'id': 1,
        'lat': 52.5,
        'lon': 13.4,
        'tags': <String, Object?>{'amenity': 'fuel'},
      });
      expect(place, isNotNull);
      expect(place!.name, 'Fuel');
      expect(place.category, 'fuel');
    });

    test('prefers shop over amenity as the category', () {
      final Place? place = OverpassPlaceMapper.fromElement(<String, Object?>{
        'type': 'node',
        'id': 1,
        'lat': 52.5,
        'lon': 13.4,
        'tags': <String, Object?>{
          'name': 'Market',
          'shop': 'supermarket',
          'amenity': 'marketplace',
        },
      });
      expect(place!.category, 'supermarket');
    });

    test('prefers website over contact:website and supports either tag', () {
      Place? from(Map<String, Object?> tags) =>
          OverpassPlaceMapper.fromElement(<String, Object?>{
            'type': 'node',
            'id': 1,
            'lat': 52.5,
            'lon': 13.4,
            'tags': <String, Object?>{'name': 'Cafe', ...tags},
          });

      expect(
        from(<String, Object?>{
          'website': 'https://website.example',
          'contact:website': 'https://contact.example',
        })!.website,
        'https://website.example',
      );
      expect(
        from(<String, Object?>{'contact:website': 'https://contact.example'})!
            .website,
        'https://contact.example',
      );
    });

    test('drops an element with no position or no usable id', () {
      expect(
        OverpassPlaceMapper.fromElement(<String, Object?>{
          'type': 'way',
          'id': 1,
          'tags': <String, Object?>{'name': 'X', 'amenity': 'cafe'},
        }),
        isNull,
      );
      expect(
        OverpassPlaceMapper.fromElement(<String, Object?>{
          'type': 'blob',
          'id': 1,
          'lat': 52.5,
          'lon': 13.4,
          'tags': <String, Object?>{'name': 'X'},
        }),
        isNull,
      );
    });

    test('never throws on hostile elements', () {
      for (final Object? raw in <Object?>[
        null,
        7,
        'x',
        <Object?>[],
        <String, Object?>{},
        <String, Object?>{'type': 'node', 'id': 0, 'lat': 0, 'lon': 0},
        <String, Object?>{
          'type': 'node',
          'id': 1,
          'lat': 'x',
          'lon': 2,
          'tags': <String, Object?>{'name': 'X'},
        },
        <String, Object?>{
          'type': 'node',
          'id': 1,
          'lat': 52.5,
          'lon': 13.4,
          'tags': <Object?>['not', 'a', 'map'],
        },
        <String, Object?>{
          'type': 'node',
          'id': 1,
          'lat': 52.5,
          'lon': 13.4,
          'tags': <String, Object?>{'name': 7, 'amenity': <Object?>[]},
        },
      ]) {
        expect(
          () => OverpassPlaceMapper.fromElement(raw),
          returnsNormally,
          reason: 'raw: $raw',
        );
      }
    });
  });
}
