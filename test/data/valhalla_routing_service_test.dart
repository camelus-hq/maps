import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/valhalla/valhalla_routing_service.dart';
import 'package:openmaps/domain/entities/cycling_options.dart';
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
    // Lane-level guidance is requested (Valhalla only emits `maneuver.lanes`
    // when `turn_lanes` is set).
    expect(body['turn_lanes'], isTrue);
  });

  test('only changed bicycle options are posted as costing_options', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      if (!request.url.path.endsWith('/height')) {
        captured = request;
      }
      return http.Response(_routeBody(), 200);
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://valhalla.example.com/',
    );

    await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.cycle,
      cycling: const CyclingOptions(
        bicycleType: BicycleType.mountain,
        useHills: 0.9,
        avoidEdges: true,
      ),
    );

    final Map<String, Object?> body =
        jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['costing'], 'bicycle');
    final Map<String, Object?> options =
        body['costing_options'] as Map<String, Object?>;
    final Map<String, Object?> bicycle =
        options['bicycle'] as Map<String, Object?>;
    expect(bicycle['bicycle_type'], 'mountain');
    expect(bicycle['use_hills'], 0.9);
    expect(bicycle['avoid_edges'], isTrue);
    // The type default speed and untouched weights are not forced on Valhalla.
    expect(bicycle.containsKey('cycling_speed'), isFalse);
    expect(bicycle.containsKey('use_roads'), isFalse);
  });

  test('an untouched bicycle panel posts no costing_options', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      if (!request.url.path.endsWith('/height')) {
        captured = request;
      }
      return http.Response(_routeBody(), 200);
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );

    await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.cycle,
      cycling: CyclingOptions.defaults,
    );

    final Map<String, Object?> body =
        jsonDecode(captured.body) as Map<String, Object?>;
    expect(body.containsKey('costing_options'), isFalse);
  });

  test('driving never forwards bicycle costing_options', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(_routeBody(), 200);
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );

    await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.drive,
      cycling: const CyclingOptions(bicycleType: BicycleType.mountain),
    );

    final Map<String, Object?> body =
        jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['costing'], 'auto');
    expect(body.containsKey('costing_options'), isFalse);
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

  test('cycling attaches the elevation profile from /height', () async {
    final List<String> paths = <String>[];
    final http.Client client = MockClient((http.Request request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/height')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'range_height': <Object?>[
              <Object?>[0, 40.0],
              <Object?>[100, 55.0],
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'trip': <String, Object?>{
            'summary': <String, Object?>{'length': 1.0, 'time': 120},
            'legs': <Object?>[
              <String, Object?>{
                'shape': '??o}@_|B',
                'summary': <String, Object?>{'length': 1.0, 'time': 120},
              },
            ],
          },
        }),
        200,
      );
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );

    final List<Route> routes = await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.cycle,
    );

    expect(paths, contains('/height'));
    expect(routes.first.elevation.isUsable, isTrue);
    expect(routes.first.elevation.maxElevation, 55.0);
  });

  test('a failing /height leaves the cycling route usable', () async {
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/height')) {
        return http.Response('boom', 500);
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'trip': <String, Object?>{
            'summary': <String, Object?>{'length': 1.0, 'time': 120},
            'legs': <Object?>[
              <String, Object?>{
                'shape': '??o}@_|B',
                'summary': <String, Object?>{'length': 1.0, 'time': 120},
              },
            ],
          },
        }),
        200,
      );
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );

    final List<Route> routes = await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.cycle,
    );

    expect(routes, hasLength(1));
    expect(routes.first.elevation.isEmpty, isTrue);
  });

  test('driving never requests elevation', () async {
    final List<String> paths = <String>[];
    final http.Client client = MockClient((http.Request request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode(<String, Object?>{
          'trip': <String, Object?>{
            'summary': <String, Object?>{'length': 1.0, 'time': 120},
            'legs': <Object?>[
              <String, Object?>{
                'shape': '??o}@_|B',
                'summary': <String, Object?>{'length': 1.0, 'time': 120},
              },
            ],
          },
        }),
        200,
      );
    });
    final ValhallaRoutingService service = ValhallaRoutingService(
      client: client,
      baseUrl: 'https://x',
    );

    await service.route(
      waypoints: <LatLon>[const LatLon(1, 2), const LatLon(3, 4)],
      mode: TravelMode.drive,
    );

    expect(paths, isNot(contains('/height')));
  });
}

/// A minimal Valhalla `/route` response body with one leg and a 2-point shape.
String _routeBody() => jsonEncode(<String, Object?>{
  'trip': <String, Object?>{
    'summary': <String, Object?>{'length': 1.0, 'time': 120},
    'legs': <Object?>[
      <String, Object?>{
        'shape': '??o}@_|B',
        'summary': <String, Object?>{'length': 1.0, 'time': 120},
      },
    ],
  },
});
