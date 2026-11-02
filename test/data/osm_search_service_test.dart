import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/osm/osm_search_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/lat_lon_bounds.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/place_category.dart';

import 'offline_client.dart';

void main() {
  group('OsmSearchService', () {
    test('searches Photon and sends the query, limit and proximity', () async {
      late http.Request captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'features': <Object?>[
              <String, Object?>{
                'type': 'Feature',
                'geometry': <String, Object?>{
                  'type': 'Point',
                  'coordinates': <Object?>[13.405, 52.52],
                },
                'properties': <String, Object?>{
                  'osm_id': 2764050762,
                  'osm_type': 'N',
                  'osm_value': 'cafe',
                  'name': 'Café X',
                },
              },
            ],
          }),
          200,
        );
      });
      final OsmSearchService service = OsmSearchService(client: client);

      final List<Place> places = await service.search(
        'coffee',
        proximity: const LatLon(52.52, 13.405),
      );

      expect(places, hasLength(1));
      expect(places.first.id, 'node/2764050762');
      expect(places.first.name, 'Café X');
      expect(captured.url.path, contains('/api'));
      expect(captured.url.queryParameters['q'], 'coffee');
      expect(captured.url.queryParameters['limit'], '10');
      expect(captured.url.queryParameters['lat'], '52.52');
      expect(captured.url.queryParameters['lon'], '13.405');
      expect(captured.headers['User-Agent'], contains('OpenMaps'));
    });

    test('searches Photon with a bbox when bounds are given', () async {
      late Uri captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request.url;
        return http.Response('{"features":[]}', 200);
      });
      final OsmSearchService service = OsmSearchService(client: client);

      await service.search(
        'cafe',
        proximity: const LatLon(52.52, 13.405),
        bounds: const LatLonBounds(
          north: 52.53,
          south: 52.51,
          east: 13.42,
          west: 13.39,
        ),
      );

      // Photon bbox order is minLon,minLat,maxLon,maxLat.
      expect(captured.queryParameters['bbox'], '13.39,52.51,13.42,52.53');
    });

    test('an empty query does not touch the network', () async {
      final http.Client client = MockClient(
        (http.Request request) async => fail('network should not be called'),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      expect(await service.search('   '), isEmpty);
    });

    test('a non-200 search becomes a NetworkException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('nope', 503),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      await expectLater(service.search('x'), throwsA(isA<NetworkException>()));
    });

    test('a malformed search body becomes a ValidationException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('{"features":[', 200),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      await expectLater(
        service.search('x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('an unexpected search shape becomes a ValidationException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('[1,2,3]', 200),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      await expectLater(
        service.search('x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a connection failure becomes an OfflineException', () async {
      final OsmSearchService service = OsmSearchService(
        client: OfflineHttpClient(),
      );
      await expectLater(service.search('x'), throwsA(isA<OfflineException>()));
      await expectLater(
        service.nearbyCategory('cafe', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<OfflineException>()),
      );
    });

    test(
      'a category browse POSTs an Overpass query for the mapped tag',
      () async {
        late http.Request captured;
        final http.Client client = MockClient((http.Request request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'elements': <Object?>[
                <String, Object?>{
                  'type': 'node',
                  'id': 2,
                  'lat': 52.502,
                  'lon': 13.402,
                  'tags': <String, Object?>{
                    'name': 'Cafe B',
                    'amenity': 'cafe',
                  },
                },
                <String, Object?>{
                  'type': 'node',
                  'id': 1,
                  'lat': 52.5001,
                  'lon': 13.4001,
                  'tags': <String, Object?>{
                    'name': 'Cafe A',
                    'amenity': 'cafe',
                  },
                },
              ],
            }),
            200,
          );
        });
        final OsmSearchService service = OsmSearchService(client: client);

        final List<Place> places = await service.nearbyCategory(
          'cafe',
          proximity: const LatLon(52.5, 13.4),
          limit: 1,
        );

        expect(captured.method, 'POST');
        expect(captured.url.path, contains('/interpreter'));
        final String body = captured.bodyFields['data'] ?? '';
        expect(body, contains('"amenity"="cafe"'));
        expect(body, contains('around:800,52.500000,13.400000'));
        expect(body, contains('out center'));
        // Sorted by distance, then trimmed to the limit.
        expect(places, hasLength(1));
        expect(places.first.id, 'node/1');
      },
    );

    test(
      'a category browse with bounds POSTs an Overpass bbox query',
      () async {
        late http.Request captured;
        final http.Client client = MockClient((http.Request request) async {
          captured = request;
          return http.Response('{"elements":[]}', 200);
        });
        final OsmSearchService service = OsmSearchService(client: client);

        await service.nearbyCategory(
          'restaurant',
          proximity: const LatLon(52.52, 13.405),
          bounds: const LatLonBounds(
            north: 52.53,
            south: 52.51,
            east: 13.42,
            west: 13.39,
          ),
        );

        final String body = captured.bodyFields['data'] ?? '';
        expect(body, contains('"amenity"="restaurant"'));
        // Overpass bounding-box order is (south, west, north, east).
        expect(body, contains('(52.510000,13.390000,52.530000,13.420000)'));
        expect(body, isNot(contains('around:')));
      },
    );

    test('maps every browse category to a filter or "unsupported"', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('{"elements":[]}', 200),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      for (final PlaceCategory category in placeCategories) {
        final List<Place> places = await service.nearbyCategory(
          category.id,
          proximity: const LatLon(52.5, 13.4),
        );
        expect(places, isEmpty, reason: 'category ${category.id}');
      }
      await expectLater(
        service.nearbyCategory('unknown', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<UnsupportedException>()),
      );
    });

    test('a non-200 category becomes a NetworkException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('slow down', 429),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      await expectLater(
        service.nearbyCategory('cafe', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('an Overpass error remark becomes a NetworkException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response(
          '{"version":0.6,"remark":"runtime error: Query timed out"}',
          200,
        ),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      await expectLater(
        service.nearbyCategory('cafe', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a malformed category body becomes a ValidationException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('<html>', 200),
      );
      final OsmSearchService service = OsmSearchService(client: client);
      await expectLater(
        service.nearbyCategory('cafe', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
