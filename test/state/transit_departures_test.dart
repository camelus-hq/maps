import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/ports/transit_routing_service.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/transit_departures.dart';

TransitStopDeparture _departure(String line, [DateTime? when]) =>
    TransitStopDeparture(
      mode: TransitMode.bus,
      departure: when ?? DateTime.utc(2026, 1, 1, 9),
      routeShortName: line,
    );

class _FixedDepartures implements TransitRoutingService {
  _FixedDepartures(this.rows);

  final List<TransitStopDeparture> rows;

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async =>
      const <TransitItinerary>[];

  @override
  Future<List<TransitStopDeparture>> departures(
    TransitDeparturesQuery query,
  ) async => rows;
}

class _Failing implements TransitRoutingService {
  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async =>
      const <TransitItinerary>[];

  @override
  Future<List<TransitStopDeparture>> departures(
    TransitDeparturesQuery query,
  ) async {
    throw const OfflineException('no network');
  }
}

/// Resolves each stop's departures only when released, so a stale response can
/// be ordered deliberately.
class _Controllable implements TransitRoutingService {
  final Map<String, Completer<List<TransitStopDeparture>>> pending =
      <String, Completer<List<TransitStopDeparture>>>{};

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async =>
      const <TransitItinerary>[];

  @override
  Future<List<TransitStopDeparture>> departures(TransitDeparturesQuery query) {
    final Completer<List<TransitStopDeparture>> completer =
        Completer<List<TransitStopDeparture>>();
    pending[query.stopId] = completer;
    return completer.future;
  }
}

void main() {
  test('opening a stop loads its departures', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    await container
        .read(transitDeparturesProvider.notifier)
        .open(stopId: 'fake:stop-a', stopName: 'North Street');

    final TransitDeparturesState state = container.read(
      transitDeparturesProvider,
    );
    expect(state.status, DeparturesStatus.data);
    expect(state.stopName, 'North Street');
    expect(state.departures, isNotEmpty);
  });

  test('an empty stop id is ignored and a failure is surfaced', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(transitDeparturesProvider.notifier)
        .open(stopId: '   ');
    expect(container.read(transitDeparturesProvider).isOpen, isFalse);

    final ProviderContainer failing = ProviderContainer(
      overrides: [transitRoutingServiceProvider.overrideWithValue(_Failing())],
    );
    addTearDown(failing.dispose);
    await failing.read(transitDeparturesProvider.notifier).open(stopId: 'de:1');
    expect(
      failing.read(transitDeparturesProvider).status,
      DeparturesStatus.error,
    );
  });

  test('a stale response never resurrects a closed board', () async {
    final _Controllable service = _Controllable();
    final ProviderContainer container = ProviderContainer(
      overrides: [transitRoutingServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final TransitDeparturesController controller = container.read(
      transitDeparturesProvider.notifier,
    );

    unawaited(controller.open(stopId: 'A'));
    unawaited(controller.open(stopId: 'B'));
    await Future<void>.delayed(Duration.zero);

    // Resolve the first (now stale) request, then the current one.
    service.pending['A']!.complete(<TransitStopDeparture>[_departure('1')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(transitDeparturesProvider).stopId, 'B');

    service.pending['B']!.complete(<TransitStopDeparture>[_departure('2')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(transitDeparturesProvider).stopId, 'B');

    controller.close();
    expect(container.read(transitDeparturesProvider).isOpen, isFalse);
  });

  test('the board keeps only the two most recent past departures', () async {
    final DateTime now = DateTime.now();
    final List<TransitStopDeparture> rows = <TransitStopDeparture>[
      for (int i = 5; i >= 1; i--)
        _departure('P$i', now.subtract(Duration(minutes: i))),
      for (int i = 1; i <= 3; i++)
        _departure('F$i', now.add(Duration(minutes: i))),
    ];
    final ProviderContainer container = ProviderContainer(
      overrides: [
        transitRoutingServiceProvider.overrideWithValue(_FixedDepartures(rows)),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transitDeparturesProvider.notifier)
        .open(stopId: 'de:1');

    final List<String> lines = container
        .read(transitDeparturesProvider)
        .departures
        .map((TransitStopDeparture d) => d.lineLabel)
        .toList();
    // The two newest past (P2, P1) then every upcoming one.
    expect(lines, <String>['P2', 'P1', 'F1', 'F2', 'F3']);
  });
}
