import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/ports/transit_routing_service.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/transit_stop_board.dart';

/// A deterministic transit service for the board tests: it generates
/// departures around the requested anchor so paging can be exercised.
class _BoardService implements TransitRoutingService {
  _BoardService({this.fail = false, this.longDistanceFirst = false});

  final bool fail;
  final bool longDistanceFirst;
  final List<TransitDeparturesQuery> queries = <TransitDeparturesQuery>[];
  int tripCalls = 0;

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async =>
      const <TransitItinerary>[];

  @override
  Future<TransitStopInfo> stopInfo(TransitStopQuery query) async {
    if (fail) {
      throw const OfflineException('no');
    }
    return TransitStopInfo(
      stopId: 'de:1',
      name: 'Central Station',
      position: query.position,
      routes: const <TransitStopRoute>[
        TransitStopRoute(
          mode: TransitMode.suburbanRail,
          routeShortName: 'S41',
          routeColor: 0xFFCB6418,
        ),
        TransitStopRoute(mode: TransitMode.subway, routeShortName: 'U8'),
      ],
    );
  }

  @override
  Future<List<TransitStopDeparture>> departures(
    TransitDeparturesQuery query,
  ) async {
    queries.add(query);
    if (fail) {
      throw const OfflineException('no');
    }
    final DateTime base = (query.time ?? DateTime.utc(2026, 1, 1, 9)).toUtc();
    final bool earlier = query.direction == TransitDeparturesDirection.earlier;
    if (longDistanceFirst) {
      return <TransitStopDeparture>[
        for (int i = 0; i < 3; i++)
          TransitStopDeparture(
            mode: i == 2 ? TransitMode.suburbanRail : TransitMode.highSpeedRail,
            departure: earlier
                ? base.subtract(Duration(minutes: (i + 1) * 5))
                : base.add(Duration(minutes: i * 5)),
            routeShortName: i == 2 ? 'S41' : 'ICE 10',
            tripId:
                'trip-${(earlier ? base.subtract(Duration(minutes: (i + 1) * 5)) : base.add(Duration(minutes: i * 5))).millisecondsSinceEpoch}',
            headsign: 'Terminus',
          ),
      ];
    }
    return <TransitStopDeparture>[
      for (int i = 0; i < 3; i++)
        TransitStopDeparture(
          mode: i.isEven ? TransitMode.suburbanRail : TransitMode.subway,
          departure: earlier
              ? base.subtract(Duration(minutes: (i + 1) * 5))
              : base.add(Duration(minutes: i * 5)),
          routeShortName: i.isEven ? 'S41' : 'U8',
          routeColor: i.isEven ? 0xFFCB6418 : null,
          tripId:
              'trip-${(earlier ? base.subtract(Duration(minutes: (i + 1) * 5)) : base.add(Duration(minutes: i * 5))).millisecondsSinceEpoch}',
          headsign: 'Terminus',
        ),
    ];
  }

  @override
  Future<TransitItinerary> trip(String tripId) async {
    tripCalls++;
    const List<LatLon> points = <LatLon>[
      LatLon(52.52, 13.41),
      LatLon(52.525, 13.415),
      LatLon(52.53, 13.42),
    ];
    return TransitItinerary(
      startTime: DateTime.utc(2026, 1, 1, 9),
      endTime: DateTime.utc(2026, 1, 1, 9, 20),
      legs: <TransitLeg>[
        TransitLeg(
          mode: TransitMode.suburbanRail,
          from: const TransitStop(name: 'A', position: LatLon(52.52, 13.41)),
          to: const TransitStop(name: 'B', position: LatLon(52.53, 13.42)),
          startTime: DateTime.utc(2026, 1, 1, 9),
          endTime: DateTime.utc(2026, 1, 1, 9, 20),
          duration: const Duration(minutes: 20),
          geometry: points,
          routeShortName: 'S41',
          routeColor: 0xFFCB6418,
          intermediateStops: const <TransitStop>[
            TransitStop(name: 'M', position: LatLon(52.525, 13.415)),
          ],
        ),
      ],
    );
  }
}

const Place _station = Place(
  id: 'node/1',
  name: 'Central Station',
  position: LatLon(52.525, 13.415),
  category: 'rail',
);

void main() {
  test(
    'opening a stop loads its lines and departures and draws the map',
    () async {
      final _BoardService service = _BoardService();
      final FakeMapService map = FakeMapService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          transitRoutingServiceProvider.overrideWithValue(service),
          mapServiceProvider.overrideWithValue(map),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(transitStopBoardProvider.notifier)
          .openFromPlace(_station);

      final TransitStopBoardState state = container.read(
        transitStopBoardProvider,
      );
      expect(state.status, StopBoardStatus.data);
      expect(state.stopId, 'de:1');
      expect(state.stopName, 'Central Station');
      expect(state.routes, hasLength(2));
      expect(state.departures, hasLength(3));
      // Two distinct lines → two drawn polylines, one per line.
      expect(service.tripCalls, 2);
      expect(state.lines, hasLength(2));
      expect(map.routeLines, hasLength(2));
      expect(map.transitStopMarkers, isNotEmpty);
    },
  );

  test('load earlier prepends, load later appends (de-duplicated)', () async {
    final _BoardService service = _BoardService();
    final FakeMapService map = FakeMapService();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        transitRoutingServiceProvider.overrideWithValue(service),
        mapServiceProvider.overrideWithValue(map),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transitStopBoardProvider.notifier)
        .openFromPlace(_station);
    final DateTime earliest = container
        .read(transitStopBoardProvider)
        .departures
        .first
        .displayDeparture;

    await container.read(transitStopBoardProvider.notifier).loadEarlier();
    final TransitStopBoardState afterEarlier = container.read(
      transitStopBoardProvider,
    );
    expect(afterEarlier.departures, hasLength(6));
    expect(
      afterEarlier.departures.first.displayDeparture.isBefore(earliest),
      isTrue,
    );
    expect(afterEarlier.loadingEarlier, isFalse);

    await container.read(transitStopBoardProvider.notifier).loadLater();
    final TransitStopBoardState afterLater = container.read(
      transitStopBoardProvider,
    );
    // The anchor departure is returned again but de-duplicated, so only the
    // genuinely later rows are appended.
    expect(afterLater.departures.length, greaterThan(6));
    final Set<String> unique = afterLater.departures
        .map(
          (TransitStopDeparture d) =>
              '${d.tripId}|${d.displayDeparture.millisecondsSinceEpoch}',
        )
        .toSet();
    expect(unique, hasLength(afterLater.departures.length));
  });

  test('closing clears the state and the drawn map lines', () async {
    final _BoardService service = _BoardService();
    final FakeMapService map = FakeMapService();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        transitRoutingServiceProvider.overrideWithValue(service),
        mapServiceProvider.overrideWithValue(map),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transitStopBoardProvider.notifier)
        .openFromPlace(_station);
    expect(map.routeLines, isNotEmpty);

    container.read(transitStopBoardProvider.notifier).close();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(transitStopBoardProvider).isOpen, isFalse);
    expect(map.routeLines, isEmpty);
    expect(map.transitStopMarkers, isEmpty);
  });

  test('a provider failure surfaces as an error state', () async {
    final _BoardService service = _BoardService(fail: true);
    final FakeMapService map = FakeMapService();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        transitRoutingServiceProvider.overrideWithValue(service),
        mapServiceProvider.overrideWithValue(map),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transitStopBoardProvider.notifier)
        .openFromPlace(_station);

    final TransitStopBoardState state = container.read(
      transitStopBoardProvider,
    );
    expect(state.status, StopBoardStatus.error);
    expect(state.departures, isEmpty);
    expect(state.error, isA<OfflineException>());
    expect(map.routeLines, isEmpty);
  });

  test(
    'tapping a departure shows its train and draws only that line',
    () async {
      final _BoardService service = _BoardService();
      final FakeMapService map = FakeMapService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          transitRoutingServiceProvider.overrideWithValue(service),
          mapServiceProvider.overrideWithValue(map),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(transitStopBoardProvider.notifier)
          .openFromPlace(_station);
      expect(map.routeLines, hasLength(2));

      final TransitStopDeparture departure = container
          .read(transitStopBoardProvider)
          .departures
          .first;
      await container
          .read(transitStopBoardProvider.notifier)
          .openTrip(departure);

      final TransitStopBoardState detail = container.read(
        transitStopBoardProvider,
      );
      expect(detail.selectedDeparture, isNotNull);
      expect(detail.tripDetail, isNotNull);
      expect(detail.tripDetail!.stops, hasLength(3));
      // Only the tapped train's line is on the map.
      expect(map.routeLines, hasLength(1));
      expect(map.routeLines.single.width, 8);

      container.read(transitStopBoardProvider.notifier).closeTrip();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(transitStopBoardProvider).tripDetail, isNull);
      expect(map.routeLines, hasLength(2));
    },
  );

  test('deselecting the place closes the board and clears the map', () async {
    final _BoardService service = _BoardService();
    final FakeMapService map = FakeMapService();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        transitRoutingServiceProvider.overrideWithValue(service),
        mapServiceProvider.overrideWithValue(map),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedPlaceProvider.notifier).select(_station);
    await container
        .read(transitStopBoardProvider.notifier)
        .openFromPlace(_station);
    expect(map.routeLines, isNotEmpty);

    // Closing the sheet clears the selected place.
    container.read(selectedPlaceProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(transitStopBoardProvider).isOpen, isFalse);
    expect(map.routeLines, isEmpty);
    expect(map.transitStopMarkers, isEmpty);
  });

  test('long-distance departures are not drawn on the map', () async {
    final _BoardService service = _BoardService(longDistanceFirst: true);
    final FakeMapService map = FakeMapService();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        transitRoutingServiceProvider.overrideWithValue(service),
        mapServiceProvider.overrideWithValue(map),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transitStopBoardProvider.notifier)
        .openFromPlace(_station);

    // The ICE/EN lines are dropped; only the local ones are drawn.
    expect(map.routeLines, hasLength(1));
    expect(container.read(transitStopBoardProvider).lines, hasLength(1));
  });
}
