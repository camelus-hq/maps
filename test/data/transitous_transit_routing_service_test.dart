import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/transitous/transitous_transit_routing_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit.dart';

import 'motis_plan_dto_test.dart' show sampleResponse;
import 'offline_client.dart';

void main() {
  const LatLon origin = LatLon(52.517, 13.389);
  const LatLon destination = LatLon(52.505, 13.301);

  test('requests /v1/plan with the query and parses the journeys', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(jsonEncode(sampleResponse()), 200);
    });
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: client,
          baseUrl: 'https://api.example.org/api/',
          userAgent: 'OpenMaps/0.1 (test)',
        );

    final List<TransitItinerary> itineraries = await service.plan(
      const TransitQuery(origin: origin, destination: destination),
    );

    expect(itineraries, hasLength(1));
    expect(captured.url.path, '/api/v1/plan');
    expect(captured.headers['User-Agent'], 'OpenMaps/0.1 (test)');
    final Map<String, String> params = captured.url.queryParameters;
    expect(params['fromPlace'], '52.517000,13.389000');
    expect(params['toPlace'], '52.505000,13.301000');
    expect(params['arriveBy'], 'false');
    expect(params['numItineraries'], '5');
    // No preference means no transitModes filter (all modes).
    expect(params.containsKey('transitModes'), isFalse);
  });

  test('sends the preferred transit modes and the arrival time', () async {
    late http.Request captured;
    final http.Client client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(jsonEncode(sampleResponse()), 200);
    });
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: client,
          baseUrl: 'https://api.example.org/api',
        );

    await service.plan(
      TransitQuery(
        origin: origin,
        destination: destination,
        timeMode: TransitTimeMode.arriveBy,
        time: DateTime.utc(2026, 5, 1, 9),
        preferredModes: const <TransitMode>{
          TransitMode.bus,
          TransitMode.subway,
        },
      ),
    );

    final Map<String, String> params = captured.url.queryParameters;
    expect(params['arriveBy'], 'true');
    expect(params['time'], '2026-05-01T09:00:00Z');
    final Set<String> modes = (params['transitModes'] ?? '').split(',').toSet();
    expect(modes, <String>{'BUS', 'SUBWAY'});
  });

  test('chains multi-stop journeys segment by segment', () async {
    final List<Uri> requests = <Uri>[];
    final http.Client client = MockClient((http.Request request) async {
      requests.add(request.url);
      return http.Response(jsonEncode(sampleResponse()), 200);
    });
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: client,
          baseUrl: 'https://api.example.org/api',
        );

    final List<TransitItinerary> itineraries = await service.plan(
      const TransitQuery(
        origin: LatLon(52.5, 13.3),
        destination: LatLon(52.6, 13.5),
        stops: <LatLon>[LatLon(52.55, 13.4)],
      ),
    );

    expect(requests, hasLength(2));
    expect(itineraries, hasLength(1));
    // Two segments of three legs each.
    expect(itineraries.first.legs, hasLength(6));
    // The second leg departs when the first segment arrives (09:23).
    expect(requests[1].queryParameters['time'], '2026-05-01T09:23:00Z');
  });

  test('a non-200 becomes a NetworkException', () async {
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient(
            (http.Request request) async => http.Response('nope', 500),
          ),
          baseUrl: 'https://x',
        );
    await expectLater(
      service.plan(
        const TransitQuery(origin: origin, destination: destination),
      ),
      throwsA(isA<NetworkException>()),
    );
  });

  test('a connection failure becomes an OfflineException', () async {
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: OfflineHttpClient(),
          baseUrl: 'https://x',
        );
    await expectLater(
      service.plan(
        const TransitQuery(origin: origin, destination: destination),
      ),
      throwsA(isA<OfflineException>()),
    );
  });

  test('a non-JSON body becomes a ValidationException, not a crash', () async {
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient(
            (http.Request request) async => http.Response('<html>', 200),
          ),
          baseUrl: 'https://x',
        );
    await expectLater(
      service.plan(
        const TransitQuery(origin: origin, destination: destination),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('an empty plan becomes a NotFoundException', () async {
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient(
            (http.Request request) async =>
                http.Response('{"itineraries":[]}', 200),
          ),
          baseUrl: 'https://x',
        );
    await expectLater(
      service.plan(
        const TransitQuery(origin: origin, destination: destination),
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('a request without a time lets the provider use "now"', () async {
    late http.Request captured;
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient((http.Request request) async {
            captured = request;
            return http.Response(jsonEncode(sampleResponse()), 200);
          }),
          baseUrl: 'https://x',
        );
    await service.plan(
      const TransitQuery(origin: origin, destination: destination),
    );
    expect(captured.url.queryParameters.containsKey('time'), isFalse);
  });

  test(
    'requests /v1/stoptimes with the stop id and parses departures',
    () async {
      late http.Request captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'stopTimes': <Object?>[
              <String, Object?>{
                'mode': 'METRO',
                'realTime': true,
                'headsign': 'Ringbahn S 41',
                'routeShortName': 'S41',
                'place': <String, Object?>{
                  'name': 'S Messe Nord/ZOB',
                  'stopId': 'de:1',
                  'track': '2',
                  'departure': '2026-11-09T10:09:00Z',
                  'scheduledDeparture': '2026-11-09T10:05:00Z',
                },
              },
            ],
          }),
          200,
        );
      });
      final TransitousTransitRoutingService service =
          TransitousTransitRoutingService(
            client: client,
            baseUrl: 'https://api.example.org/api/',
            userAgent: 'OpenMaps/0.1 (test)',
          );

      final List<TransitStopDeparture> departures = await service.departures(
        const TransitDeparturesQuery(stopId: 'de:1', limit: 4),
      );

      expect(departures, hasLength(1));
      expect(departures.first.lineLabel, 'S41');
      expect(captured.url.path, '/api/v6/stoptimes');
      expect(captured.url.queryParameters['stopId'], 'de:1');
      expect(captured.url.queryParameters['n'], '4');
      expect(captured.headers['User-Agent'], 'OpenMaps/0.1 (test)');
    },
  );

  test('departures rejects an empty stop id without a request', () async {
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient(
            (http.Request request) async => http.Response('{}', 200),
          ),
          baseUrl: 'https://x',
        );
    await expectLater(
      service.departures(const TransitDeparturesQuery(stopId: '  ')),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'departures by coordinate send center/radius and the direction',
    () async {
      late http.Request captured;
      final TransitousTransitRoutingService service =
          TransitousTransitRoutingService(
            client: MockClient((http.Request request) async {
              captured = request;
              return http.Response('{"stopTimes":[]}', 200);
            }),
            baseUrl: 'https://api.example.org/api',
          );

      await service.departures(
        const TransitDeparturesQuery(
          position: LatLon(52.5216, 13.41114),
          direction: TransitDeparturesDirection.earlier,
          limit: 8,
        ),
      );

      final Map<String, String> params = captured.url.queryParameters;
      expect(params['center'], '52.521600,13.411140');
      expect(params['radius'], '250');
      expect(params['direction'], 'EARLIER');
      expect(params.containsKey('stopId'), isFalse);
    },
  );

  test('stopInfo requests /v6/stop and parses the lines', () async {
    late http.Request captured;
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient((http.Request request) async {
            captured = request;
            return http.Response(
              jsonEncode(<String, Object?>{
                'place': <String, Object?>{
                  'name': 'S+U Alexanderplatz',
                  'stopId': 'de:1',
                  'lat': 52.5216,
                  'lon': 13.41114,
                },
                'routes': <Object?>[
                  <String, Object?>{
                    'mode': 'SUBURBAN',
                    'routeShortName': 'S41',
                    'routeColor': 'cb6418',
                  },
                  <String, Object?>{'mode': 'SUBWAY', 'routeShortName': 'U8'},
                ],
              }),
              200,
            );
          }),
          baseUrl: 'https://api.example.org/api',
        );

    final TransitStopInfo info = await service.stopInfo(
      const TransitStopQuery(stopId: 'de:1'),
    );

    expect(captured.url.path, '/api/v6/stop');
    expect(captured.url.queryParameters['stopId'], 'de:1');
    expect(info.name, 'S+U Alexanderplatz');
    expect(
      info.routes.map((TransitStopRoute r) => r.lineLabel).toList(),
      <String>['S41', 'U8'],
    );
    expect(info.routes.first.displayColor, 0xFFCB6418);
  });

  test('stopInfo resolves a coordinate via reverse-geocode first', () async {
    final List<Uri> requests = <Uri>[];
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient((http.Request request) async {
            requests.add(request.url);
            if (request.url.path.endsWith('/v1/reverse-geocode')) {
              return http.Response(
                jsonEncode(<Object?>[
                  <String, Object?>{'type': 'STOP', 'id': 'de:42'},
                ]),
                200,
              );
            }
            return http.Response(
              jsonEncode(<String, Object?>{
                'place': <String, Object?>{'name': 'Hbf', 'stopId': 'de:42'},
                'routes': <Object?>[
                  <String, Object?>{
                    'mode': 'REGIONAL_RAIL',
                    'routeShortName': 'RB14',
                  },
                ],
              }),
              200,
            );
          }),
          baseUrl: 'https://api.example.org/api',
        );

    final TransitStopInfo info = await service.stopInfo(
      const TransitStopQuery(position: LatLon(52.5, 13.4)),
    );

    expect(requests, hasLength(2));
    expect(requests.first.path, '/api/v1/reverse-geocode');
    expect(requests.first.queryParameters['type'], 'STOP');
    expect(requests.last.path, '/api/v6/stop');
    expect(requests.last.queryParameters['stopId'], 'de:42');
    expect(info.stopId, 'de:42');
    expect(info.routes.single.lineLabel, 'RB14');
  });

  test('trip requests /v6/trip and parses the leg', () async {
    late http.Request captured;
    final TransitousTransitRoutingService service =
        TransitousTransitRoutingService(
          client: MockClient((http.Request request) async {
            captured = request;
            return http.Response(
              jsonEncode(<String, Object?>{
                'startTime': '2026-11-12T10:00:00Z',
                'endTime': '2026-11-12T10:20:00Z',
                'legs': <Object?>[
                  <String, Object?>{
                    'mode': 'SUBURBAN',
                    'startTime': '2026-11-12T10:00:00Z',
                    'endTime': '2026-11-12T10:20:00Z',
                    'routeShortName': 'S41',
                    'from': <String, Object?>{
                      'name': 'A',
                      'lat': 52.52,
                      'lon': 13.41,
                    },
                    'to': <String, Object?>{
                      'name': 'B',
                      'lat': 52.53,
                      'lon': 13.42,
                    },
                  },
                ],
              }),
              200,
            );
          }),
          baseUrl: 'https://api.example.org/api',
        );

    final TransitItinerary itinerary = await service.trip('trip 1');
    expect(captured.url.path, '/api/v6/trip');
    expect(captured.url.queryParameters['tripId'], 'trip 1');
    expect(captured.url.queryParameters['detailedLegs'], 'true');
    expect(itinerary.legs.first.routeShortName, 'S41');
  });
}
