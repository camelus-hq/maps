import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/mapbox/mapbox_search_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/lat_lon_bounds.dart';
import 'package:openmaps/domain/entities/place.dart';

import 'offline_client.dart';

void main() {
  group('MapboxSearchService', () {
    test('parses features and sends the token', () async {
      late Uri captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request.url;
        return http.Response(
          '{"features":[{"id":"poi.1","text":"Coffee","center":[13.4,52.5],'
          '"properties":{"category":"cafe"}}]}',
          200,
        );
      });
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );

      final List<Place> places = await service.search('coffee');

      expect(places, hasLength(1));
      expect(places.first.name, 'Coffee');
      expect(captured.queryParameters['access_token'], 'pk.test');
      expect(captured.path, contains('/mapbox.places/coffee.json'));
    });

    test('caps results at the limit', () async {
      final String feature = '{"id":"p","text":"X","center":[13.4,52.5]}';
      final String body =
          '{"features":[${List<String>.filled(50, feature).join(',')}]}';
      final http.Client client = MockClient(
        (http.Request request) async => http.Response(body, 200),
      );
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );
      expect(await service.search('x'), hasLength(10));
    });

    test('non-200 becomes a NetworkException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('nope', 500),
      );
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );
      await expectLater(service.search('x'), throwsA(isA<NetworkException>()));
    });

    test('a malformed body becomes a ValidationException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('[1,2,3]', 200),
      );
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );
      await expectLater(
        service.search('x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'a non-JSON body becomes a ValidationException, not a crash',
      () async {
        final http.Client client = MockClient(
          (http.Request request) async =>
              http.Response('<html>Bad gateway</html>', 200),
        );
        final MapboxSearchService service = MapboxSearchService(
          client: client,
          accessToken: 'pk.test',
        );
        await expectLater(
          service.search('x'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('a truncated JSON body becomes a ValidationException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('{"features":[', 200),
      );
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );
      await expectLater(
        service.search('x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('search passes a bbox when bounds are given', () async {
      late Uri captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request.url;
        return http.Response('{"features":[]}', 200);
      });
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );

      await service.search(
        'cafe',
        bounds: const LatLonBounds(
          north: 52.53,
          south: 52.51,
          east: 13.42,
          west: 13.39,
        ),
      );

      // Mapbox bbox order is minLon,minLat,maxLon,maxLat.
      expect(captured.queryParameters['bbox'], '13.39,52.51,13.42,52.53');
    });

    test('passes proximity to bias results', () async {
      late Uri captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request.url;
        return http.Response('{"features":[]}', 200);
      });
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );

      await service.search('cafe', proximity: const LatLon(52.52, 13.405));

      expect(captured.queryParameters['proximity'], '13.405,52.52');
    });

    test(
      'nearbyCategory queries the category endpoint with proximity',
      () async {
        late Uri captured;
        final http.Client client = MockClient((http.Request request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(<String, Object?>{
              'features': <Object?>[
                <String, Object?>{
                  'type': 'Feature',
                  'properties': <String, Object?>{
                    'name': 'Near Cafe',
                    'mapbox_id': 'poi.x',
                    'poi_category': <Object?>['cafe'],
                    'full_address': 'A, Berlin',
                    'coordinates': <String, Object?>{
                      'longitude': 13.4,
                      'latitude': 52.5,
                    },
                  },
                },
              ],
            }),
            200,
          );
        });
        final MapboxSearchService service = MapboxSearchService(
          client: client,
          accessToken: 'pk.test',
        );

        final List<Place> places = await service.nearbyCategory(
          'cafe',
          proximity: const LatLon(52.5, 13.4),
        );

        expect(places, hasLength(1));
        expect(places.first.name, 'Near Cafe');
        expect(captured.path, contains('/search/searchbox/v1/category/cafe'));
        expect(captured.queryParameters['proximity'], '13.4,52.5');
      },
    );

    test('nearbyCategory drops results outside the given bounds', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, Object?>{
            'features': <Object?>[
              <String, Object?>{
                'properties': <String, Object?>{
                  'name': 'Inside',
                  'mapbox_id': 'poi.in',
                  'coordinates': <String, Object?>{
                    'longitude': 13.40,
                    'latitude': 52.52,
                  },
                },
              },
              <String, Object?>{
                'properties': <String, Object?>{
                  'name': 'Outside',
                  'mapbox_id': 'poi.out',
                  'coordinates': <String, Object?>{
                    'longitude': 13.60,
                    'latitude': 52.52,
                  },
                },
              },
            ],
          }),
          200,
        ),
      );
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );

      final List<Place> places = await service.nearbyCategory(
        'cafe',
        proximity: const LatLon(52.52, 13.405),
        bounds: const LatLonBounds(
          north: 52.53,
          south: 52.51,
          east: 13.42,
          west: 13.39,
        ),
      );

      expect(places.map((Place p) => p.name), <String>['Inside']);
    });

    test(
      'nearbyCategory passes the Mapbox category id for a mapped one',
      () async {
        late Uri captured;
        final http.Client client = MockClient((http.Request request) async {
          captured = request.url;
          return http.Response('{"features":[]}', 200);
        });
        final MapboxSearchService service = MapboxSearchService(
          client: client,
          accessToken: 'pk.test',
        );

        await service.nearbyCategory(
          'fuel',
          proximity: const LatLon(52.5, 13.4),
        );

        expect(captured.path, contains('/category/gas_station'));
      },
    );

    test(
      'nearbyCategory throws for a category Mapbox has no index for',
      () async {
        final http.Client client = MockClient(
          (http.Request request) async => fail('network should not be called'),
        );
        final MapboxSearchService service = MapboxSearchService(
          client: client,
          accessToken: 'pk.test',
        );
        await expectLater(
          service.nearbyCategory(
            'drinking_water',
            proximity: const LatLon(52.5, 13.4),
          ),
          throwsA(isA<UnsupportedException>()),
        );
      },
    );

    test('nearbyCategory non-200 becomes a NetworkException', () async {
      final http.Client client = MockClient(
        (http.Request request) async => http.Response('nope', 404),
      );
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );
      await expectLater(
        service.nearbyCategory('cafe', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a connection failure becomes an OfflineException', () async {
      final MapboxSearchService service = MapboxSearchService(
        client: OfflineHttpClient(),
        accessToken: 'pk.test',
      );
      await expectLater(service.search('x'), throwsA(isA<OfflineException>()));
      await expectLater(
        service.nearbyCategory('cafe', proximity: const LatLon(52.5, 13.4)),
        throwsA(isA<OfflineException>()),
      );
    });

    test('an empty query does not touch the network', () async {
      final http.Client client = MockClient((http.Request request) async {
        fail('network should not be called');
      });
      final MapboxSearchService service = MapboxSearchService(
        client: client,
        accessToken: 'pk.test',
      );
      expect(await service.search('   '), isEmpty);
    });
  });
}
