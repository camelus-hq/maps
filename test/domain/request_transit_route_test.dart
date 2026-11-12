import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/core/errors/result.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/ports/transit_routing_service.dart';
import 'package:openmaps/domain/usecases/request_transit_route.dart';

/// A stub planner that returns canned journeys or throws.
class _StubTransitService implements TransitRoutingService {
  _StubTransitService({
    this.itineraries = const <TransitItinerary>[],
    this.error,
  });

  final List<TransitItinerary> itineraries;
  final AppException? error;

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async {
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return itineraries;
  }

  @override
  Future<List<TransitStopDeparture>> departures(
    TransitDeparturesQuery query,
  ) async {
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return const <TransitStopDeparture>[];
  }

  @override
  Future<TransitStopInfo> stopInfo(TransitStopQuery query) async {
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return const TransitStopInfo(stopId: 'stub', name: 'Stub');
  }

  @override
  Future<TransitItinerary> trip(String tripId) async {
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    throw const NotFoundException('no trip');
  }
}

TransitLeg _ride({int minutes = 10}) => TransitLeg(
  mode: TransitMode.bus,
  from: const TransitStop(name: 'A'),
  to: const TransitStop(name: 'B'),
  startTime: DateTime.utc(2026, 1, 1, 9),
  endTime: DateTime.utc(2026, 1, 1, 9, minutes),
  duration: Duration(minutes: minutes),
  routeShortName: '1',
);

TransitLeg _walk({double meters = 100, int minutes = 5}) => TransitLeg(
  mode: TransitMode.walk,
  from: const TransitStop(name: 'A'),
  to: const TransitStop(name: 'B'),
  startTime: DateTime.utc(2026, 1, 1, 8),
  endTime: DateTime.utc(2026, 1, 1, 8, minutes),
  duration: Duration(minutes: minutes),
  distanceMeters: meters,
);

TransitItinerary _itinerary(List<TransitLeg> legs) => TransitItinerary(
  legs: legs,
  startTime: DateTime.utc(2026, 1, 1, 8),
  endTime: DateTime.utc(2026, 1, 1, 9),
);

const TransitQuery _query = TransitQuery(
  origin: LatLon(52.5, 13.3),
  destination: LatLon(52.6, 13.5),
);

void main() {
  test('returns Ok with the provider journeys', () async {
    final TransitItinerary itinerary = _itinerary(<TransitLeg>[_ride()]);
    final Result<List<TransitItinerary>> result = await RequestTransitRoute(
      _StubTransitService(itineraries: <TransitItinerary>[itinerary]),
    )(_query);

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, hasLength(1));
  });

  test('an empty plan becomes NotFoundException', () async {
    final Result<List<TransitItinerary>> result = await RequestTransitRoute(
      _StubTransitService(),
    )(_query);
    expect(result.errorOrNull, isA<NotFoundException>());
  });

  test('a provider failure is surfaced as a typed error', () async {
    final Result<List<TransitItinerary>> result = await RequestTransitRoute(
      _StubTransitService(error: const OfflineException('offline')),
    )(_query);
    expect(result.errorOrNull, isA<OfflineException>());
    expect(result.errorOrNull?.isOffline, isTrue);
  });

  test('an untyped throw is wrapped as UnknownException', () async {
    final Result<List<TransitItinerary>> result = await RequestTransitRoute(
      _Thrower(),
    )(_query);
    expect(result.errorOrNull, isA<UnknownException>());
  });

  test('"Fewer transfers" ranks journeys by changes', () async {
    final TransitItinerary manyChanges = _itinerary(<TransitLeg>[
      _ride(minutes: 5),
      _ride(minutes: 5),
      _ride(minutes: 5),
    ]);
    final TransitItinerary direct = _itinerary(<TransitLeg>[
      _ride(minutes: 30),
    ]);

    final Result<List<TransitItinerary>> result = await RequestTransitRoute(
      _StubTransitService(itineraries: <TransitItinerary>[manyChanges, direct]),
    )(_query.copyWithFewerTransfers());

    expect(result.valueOrNull?.first, same(direct));
  });

  test('"Less walking" ranks journeys by walking distance', () async {
    final TransitItinerary lotsOfWalking = _itinerary(<TransitLeg>[
      _walk(meters: 900),
      _ride(),
    ]);
    final TransitItinerary littleWalking = _itinerary(<TransitLeg>[
      _walk(meters: 100),
      _ride(),
    ]);

    final Result<List<TransitItinerary>> result = await RequestTransitRoute(
      _StubTransitService(
        itineraries: <TransitItinerary>[lotsOfWalking, littleWalking],
      ),
    )(_query.copyWithLessWalking());

    expect(result.valueOrNull?.first, same(littleWalking));
  });
}

class _Thrower implements TransitRoutingService {
  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async {
    throw StateError('boom');
  }

  @override
  Future<List<TransitStopDeparture>> departures(
    TransitDeparturesQuery query,
  ) async {
    throw StateError('boom');
  }

  @override
  Future<TransitStopInfo> stopInfo(TransitStopQuery query) async {
    throw StateError('boom');
  }

  @override
  Future<TransitItinerary> trip(String tripId) async {
    throw StateError('boom');
  }
}

extension on TransitQuery {
  TransitQuery copyWithFewerTransfers() => TransitQuery(
    origin: origin,
    destination: destination,
    fewerTransfers: true,
  );

  TransitQuery copyWithLessWalking() =>
      TransitQuery(origin: origin, destination: destination, lessWalking: true);
}
