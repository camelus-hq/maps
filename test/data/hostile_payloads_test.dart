import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/mapbox_geocoding_mapper.dart';
import 'package:openmaps/data/dto/motis_plan_dto.dart';
import 'package:openmaps/data/dto/overpass_place_mapper.dart';
import 'package:openmaps/data/dto/photon_place_mapper.dart';
import 'package:openmaps/data/dto/place_dto.dart';
import 'package:openmaps/data/dto/valhalla_route_dto.dart';
import 'package:openmaps/data/local/prefs_live_share_store.dart';
import 'package:openmaps/data/nostr/live_location_payload.dart';
import 'package:openmaps/data/valhalla/polyline_codec.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';

/// Malformed / truncated / oversized external payloads must never throw — a
/// bad field drops the entry (AGENTS.md "Never crash").
void main() {
  test('mapper never throws on hostile features', () {
    final List<Object?> hostile = <Object?>[
      null,
      42,
      'a string',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{
        'id': 1,
        'text': 'x',
        'center': <Object?>[1, 2],
      },
      <String, Object?>{
        'id': 'a',
        'center': <Object?>[1, 2],
      },
      <String, Object?>{
        'id': 'a',
        'text': '',
        'place_name': '',
        'center': <Object?>[1, 2],
      },
      <String, Object?>{'id': 'a', 'text': 'x'},
      <String, Object?>{'id': 'a', 'text': 'x', 'center': 'nope'},
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[double.nan, 1],
      },
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[1, double.infinity],
      },
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[999, 1],
      },
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[1],
      },
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[1, 2, 3, 4],
      },
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[1, 2],
        'properties': <Object?>[],
      },
      <String, Object?>{
        'id': 'a',
        'text': 'x',
        'center': <Object?>[1, 2],
        'properties': <String, Object?>{'categories': 'oops'},
      },
    ];

    for (final Object? feature in hostile) {
      expect(
        () => MapboxGeocodingMapper.fromFeature(feature),
        returnsNormally,
        reason: 'feature: $feature',
      );
    }
  });

  test('a valid feature inside a garbage list is still parsed', () {
    final Object? place = MapboxGeocodingMapper.fromFeature(<String, Object?>{
      'id': 'ok',
      'text': 'Good',
      'center': <Object?>[13.4, 52.5],
      'extra': <String, Object?>{'ignored': true},
    });
    expect(place, isNotNull);
  });

  test('the Photon and Overpass mappers never throw on hostile payloads', () {
    final List<Object?> hostile = <Object?>[
      null,
      42,
      'a string',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{'geometry': <Object?>[], 'properties': 'x'},
      <String, Object?>{'type': 'node', 'id': 1},
      <String, Object?>{
        'type': 'node',
        'id': 1,
        'lat': double.nan,
        'lon': 13.4,
        'tags': <String, Object?>{'name': 'X'},
      },
      <String, Object?>{
        'type': 'way',
        'id': 1,
        'center': <String, Object?>{'lat': 999, 'lon': 999},
        'tags': <String, Object?>{'name': 'X'},
      },
      <String, Object?>{
        'type': 'node',
        'id': 1,
        'lat': 52.5,
        'lon': 13.4,
        'tags': <Object?>['not', 'a', 'map'],
      },
    ];
    for (final Object? raw in hostile) {
      expect(
        () => PhotonPlaceMapper.fromFeature(raw),
        returnsNormally,
        reason: 'photon: $raw',
      );
      expect(
        () => OverpassPlaceMapper.fromElement(raw),
        returnsNormally,
        reason: 'overpass: $raw',
      );
    }
  });

  test('Valhalla route DTO never throws on hostile responses', () {
    final List<Object?> hostile = <Object?>[
      null,
      42,
      'x',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{'trip': 'x'},
      <String, Object?>{
        'trip': <String, Object?>{'legs': 'x'},
      },
      <String, Object?>{
        'trip': <String, Object?>{
          'legs': <Object?>['x', 7],
        },
      },
      <String, Object?>{
        'trip': <String, Object?>{
          'summary': 'x',
          'legs': <Object?>[
            <String, Object?>{
              'shape': <Object?>[1, 2],
              'maneuvers': <Object?>['x', 3, null],
            },
          ],
        },
      },
      <String, Object?>{'alternates': 'x'},
      <String, Object?>{
        'trip': <String, Object?>{
          'summary': <String, Object?>{'length': double.nan, 'time': -1},
        },
        'alternates': <Object?>[null, 5, 'x'],
      },
    ];
    for (final Object? raw in hostile) {
      expect(
        () => ValhallaRouteDto.routesFromResponse(raw),
        returnsNormally,
        reason: 'response: $raw',
      );
    }
  });

  test('the MOTIS plan DTO never throws on hostile responses', () {
    final List<Object?> hostile = <Object?>[
      null,
      42,
      'x',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{'itineraries': 'x'},
      <String, Object?>{
        'itineraries': <Object?>['x', 7, null],
      },
      <String, Object?>{
        'itineraries': <Object?>[
          <String, Object?>{
            'legs': <Object?>['x', 3],
          },
        ],
      },
      <String, Object?>{
        'itineraries': <Object?>[
          <String, Object?>{
            'startTime': 'not-a-time',
            'endTime': 7,
            'legs': <Object?>[
              <String, Object?>{
                'mode': 5,
                'startTime': <Object?>[],
                'endTime': null,
                'from': 'nope',
                'to': <String, Object?>{},
                'legGeometry': <String, Object?>{'points': 7, 'precision': 99},
              },
            ],
          },
        ],
      },
      <String, Object?>{
        'itineraries': <Object?>[
          <String, Object?>{
            'legs': <Object?>[
              <String, Object?>{
                'mode': 'WALK',
                'startTime': '2026-05-01T09:00:00Z',
                'endTime': '2026-05-01T09:01:00Z',
                'duration': -5,
                'distance': double.nan,
                'from': <String, Object?>{'lat': 999, 'lon': 13},
                'to': <String, Object?>{'name': 'ok', 'lat': 52.5, 'lon': 13.4},
                'legGeometry': <String, Object?>{
                  'points': String.fromCharCodes(
                    List<int>.generate(60000, (int i) => 200),
                  ),
                  'precision': 7,
                },
              },
            ],
          },
        ],
      },
    ];
    for (final Object? raw in hostile) {
      expect(
        () => MotisPlanDto.itinerariesFromResponse(raw),
        returnsNormally,
        reason: 'response: $raw',
      );
    }
  });

  test('polyline decoder never throws on hostile / oversized input', () {
    for (final String encoded in <String>[
      '',
      '\u0000',
      'garbage',
      '?????',
      '~',
      '\\',
      String.fromCharCodes(List<int>.generate(100000, (int i) => 200)),
    ]) {
      expect(
        () => decodePolyline(encoded),
        returnsNormally,
        reason: 'length: ${encoded.length}',
      );
    }
  });

  test('PlaceDto.decodeList never throws on hostile stored JSON', () {
    for (final String? raw in <String?>[
      null,
      '',
      'not json',
      '{"not":"a list"}',
      '[null, 1, "x", {"id":5}]',
      '[{"id":"a","name":"","lat":1,"lon":2}]',
      '[{"id":"a","name":"n","lat":999,"lon":2}]',
      '[{"id":"a","name":"n","lat":"x","lon":2}]',
    ]) {
      expect(
        () => PlaceDto.decodeList(raw),
        returnsNormally,
        reason: 'raw: $raw',
      );
    }
  });

  test('a round-tripped place survives decodeList', () {
    const Place place = Place(
      id: 'poi.1',
      name: 'Café',
      position: LatLon(52.5, 13.4),
    );
    final List<Place> decoded = PlaceDto.decodeList(
      PlaceDto.encodeList(<Place>[place]),
    );
    expect(decoded, hasLength(1));
    expect(decoded.first.id, 'poi.1');
  });

  test('live-location payload decoding never throws on hostile input', () {
    for (final Object? raw in <Object?>[
      null,
      42,
      true,
      <Object?>[],
      'not json',
      '{"v":1,"t":"update"}',
      <String, Object?>{'v': 1, 't': 'update', 'session': 's'},
      <String, Object?>{
        'v': 1,
        't': 'update',
        'session': 's',
        'at': 'x',
        'exp': 'y',
      },
      <String, Object?>{
        'v': 1,
        't': 'update',
        'session': 's' * 100,
        'at': 1,
        'exp': 2,
        'lat': 999,
        'lon': 999,
      },
      <String, Object?>{
        'v': 2,
        't': 'update',
        'session': 's',
        'at': 1,
        'exp': 2,
      },
      <String, Object?>{'type': 'live-location', 'data': <Object?>[]},
    ]) {
      expect(
        () => LiveLocationPayload.decode(raw),
        returnsNormally,
        reason: 'raw: $raw',
      );
    }
  });

  test('the live-share session store never throws on hostile JSON', () {
    for (final Object? raw in <Object?>[
      null,
      '',
      'not json',
      '{"id":"x"}',
      '[]',
      <String, Object?>{},
      <String, Object?>{
        'id': 'x',
        'recipients': 'nope',
        'startedAt': 1,
        'expiresAt': 2,
      },
      <String, Object?>{
        'id': 'x' * 100,
        'recipients': <Object?>[1, null, 'nope'],
        'startedAt': 'x',
        'expiresAt': 'y',
      },
      <String, Object?>{
        'id': 'x',
        'recipients': <Object?>[],
        'startedAt': 99999999999999,
        'expiresAt': 99999999999999,
      },
    ]) {
      expect(
        () => PrefsLiveShareStore.decodeSession(raw),
        returnsNormally,
        reason: 'raw: $raw',
      );
    }
  });
}
