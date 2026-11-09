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
      expect(captured.url.path, '/api/v1/stoptimes');
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
}
