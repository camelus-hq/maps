import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/valhalla/valhalla_routing_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';

import 'offline_client.dart';

void main() {
  test('posts a Valhalla route request and parses the response', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, Object?>{
          'trip': <String, Object?>{
            'summary': <String, Object?>{'length': 1.0, 'time': 120},
            'legs': <Object?>[
              <String, Object?>{
                'shape': '??o}@_|B',
                'summary': <String, Object?>{'length': 1.0, 'time': 120},
                'maneuvers': <Object?>[],
              },
            ],
          },
        }),
        200,
      );
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://valhalla.example.com/',
    );

    final List<Route> routes = await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.walk,
    );

    expect(routes, hasLength(1));
    expect(captured.url.toString(), 'https://valhalla.example.com/route');
    final Map<String, Object?> body =
        jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['costing'], 'pedestrian');
    expect(body['locations'], hasLength(2));
  });

  test('non-200 becomes a NetworkException', () async {
    final http.Client client = MockClient(
      (http.Request request) async => http.Response('nope', 500),
    );
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );
    await expectLater(
      service.route(
        waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
        mode: TravelMode.drive,
      ),
      throwsA(isA<NetworkException>()),
    );
  });

  test('a connection failure becomes an OfflineException', () async {
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: OfflineHttpClient(),
      baseUrl: 'https://x',
    );
    await expectLater(
      service.route(
        waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
        mode: TravelMode.drive,
      ),
      throwsA(isA<OfflineException>()),
    );
  });

  test('an empty trip becomes a NotFoundException', () async {
    final http.Client client = MockClient(
      (http.Request request) async => http.Response('{}', 200),
    );
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );
    await expectLater(
      service.route(
        waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
        mode: TravelMode.drive,
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('a non-JSON body becomes a ValidationException, not a crash', () async {
    final http.Client client = MockClient(
      (http.Request request) async => http.Response('<html>oops</html>', 200),
    );
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );
    await expectLater(
      service.route(
        waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
        mode: TravelMode.drive,
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('fewer than two waypoints is a ValidationException', () async {
    final http.Client client = MockClient(
      (http.Request request) async => http.Response('{}', 200),
    );
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );
    await expectLater(
      service.route(
        waypoints: <LatLon>[const LatLon(1, 2)],
        mode: TravelMode.drive,
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
