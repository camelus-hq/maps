import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/photon_place_mapper.dart';
import 'package:openmaps/domain/entities/place.dart';

void main() {
  group('PhotonPlaceMapper', () {
    test('maps an OSM node feature to a Place with an OSM reference id', () {
      final Place? place = PhotonPlaceMapper.fromFeature(<String, Object?>{
        'type': 'Feature',
        'geometry': <String, Object?>{
          'type': 'Point',
          'coordinates': <Object?>[13.405, 52.52],
        },
        'properties': <String, Object?>{
          'osm_id': 2764050762,
          'osm_type': 'N',
          'osm_key': 'amenity',
          'osm_value': 'cafe',
          'name': 'Café X',
          'street': 'Grunerstraße',
          'housenumber': '7',
          'postcode': '10179',
          'city': 'Berlin',
          'country': 'Deutschland',
        },
      });

      expect(place, isNotNull);
      expect(place!.id, 'node/2764050762');
      expect(place.name, 'Café X');
      expect(place.position.latitude, 52.52);
      expect(place.position.longitude, 13.405);
      expect(place.category, 'cafe');
      expect(place.address, '7 Grunerstraße, 10179 Berlin, Deutschland');
    });

    test('maps W/R osm_type to way/relation references', () {
      Place? from(String type) =>
          PhotonPlaceMapper.fromFeature(<String, Object?>{
            'geometry': <String, Object?>{
              'coordinates': <Object?>[13.4, 52.5],
            },
            'properties': <String, Object?>{
              'osm_id': 42,
              'osm_type': type,
              'name': 'X',
            },
          });
      expect(from('W')!.id, 'way/42');
      expect(from('R')!.id, 'relation/42');
    });

    test('falls back to a street address for an unnamed feature', () {
      final Place? place = PhotonPlaceMapper.fromFeature(<String, Object?>{
        'geometry': <String, Object?>{
          'coordinates': <Object?>[13.4, 52.5],
        },
        'properties': <String, Object?>{
          'osm_id': 1,
          'osm_type': 'W',
          'street': 'Main Street',
          'housenumber': '12',
        },
      });
      expect(place, isNotNull);
      expect(place!.name, '12 Main Street');
    });

    test('drops a feature with no OSM id, position or name', () {
      expect(
        PhotonPlaceMapper.fromFeature(<String, Object?>{
          'geometry': <String, Object?>{
            'coordinates': <Object?>[13.4, 52.5],
          },
          'properties': <String, Object?>{'name': 'No id'},
        }),
        isNull,
      );
      expect(
        PhotonPlaceMapper.fromFeature(<String, Object?>{
          'geometry': <String, Object?>{
            'coordinates': <Object?>['x', 'y'],
          },
          'properties': <String, Object?>{'osm_id': 1, 'osm_type': 'N'},
        }),
        isNull,
      );
      expect(
        PhotonPlaceMapper.fromFeature(<String, Object?>{
          'geometry': <String, Object?>{
            'coordinates': <Object?>[13.4, 52.5],
          },
          'properties': <String, Object?>{'osm_id': 1, 'osm_type': 'N'},
        }),
        isNull,
      );
    });

    test('never throws on hostile features', () {
      for (final Object? raw in <Object?>[
        null,
        7,
        'x',
        <Object?>[],
        <String, Object?>{},
        <String, Object?>{'geometry': 'x', 'properties': 'y'},
        <String, Object?>{
          'geometry': <String, Object?>{
            'coordinates': <Object?>[999, 999],
          },
          'properties': <String, Object?>{'osm_id': 1, 'osm_type': 'N'},
        },
        <String, Object?>{
          'geometry': <String, Object?>{
            'coordinates': <Object?>[13.4, 52.5],
          },
          'properties': <String, Object?>{'osm_id': 'nope', 'osm_type': 'Z'},
        },
      ]) {
        expect(
          () => PhotonPlaceMapper.fromFeature(raw),
          returnsNormally,
          reason: 'raw: $raw',
        );
      }
    });
  });
}
