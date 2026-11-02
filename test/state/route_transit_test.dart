import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/entities/transit_stop_marker.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/transit_routing_service.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

class _AlwaysFailingTransit implements TransitRoutingService {
  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async {
    throw const TransitFailure();
  }
}

class TransitFailure implements Exception {
  const TransitFailure();
}

void main() {
  const Place origin = Place(
    id: 'transit-origin',
    name: 'Origin',
    position: LatLon(52.52, 13.4),
  );
  const Place destination = Place(
    id: 'transit-destination',
    name: 'Destination',
    position: LatLon(52.5, 13.3),
  );

  test('planTransit fills the state and draws the selected journey', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(routeControllerProvider.notifier)
        .planTransit(origin: origin, destination: destination);

    final RouteState state = container.read(routeControllerProvider);
    expect(state.mode, TravelMode.transit);
    expect(state.isTransit, isTrue);
    expect(state.status, RouteStatus.data);
    expect(state.itineraries, hasLength(2));
    expect(state.selectedItinerary, isNotNull);
    expect(state.routes, isEmpty);

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    // One styled line per leg: a dashed walk, a coloured ride, a dashed walk.
    expect(map.routeLines, hasLength(3));
    expect(map.routeLines.first.dashed, isTrue);
    expect(map.routeLines.first.color, transitWalkColor);
    expect(map.routeLines[1].dashed, isFalse);
    expect(map.routeLines[1].color, 0xFF1F6FB2); // the operator's own colour
    expect(map.routeLines[1].points.length, greaterThan(2));
    expect(map.routeLines.last.dashed, isTrue);

    // One circle per stop: a small dot at the stop called at, larger circles
    // where the traveller boards/alights (in the line's colour).
    expect(map.transitStopMarkers, hasLength(3));
    final List<TransitStopMarker> boards = map.transitStopMarkers
        .where((TransitStopMarker marker) => marker.isBoard)
        .toList(growable: false);
    final List<TransitStopMarker> passes = map.transitStopMarkers
        .where((TransitStopMarker marker) => !marker.isBoard)
        .toList(growable: false);
    expect(boards, hasLength(2));
    expect(passes, hasLength(1));
    expect(boards.first.color, 0xFF1F6FB2);
    expect(passes.first.color, 0xFF1F6FB2);
  });

  test('leaving transit clears the stop circles', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.planTransit(origin: origin, destination: destination);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.transitStopMarkers, isNotEmpty);

    await controller.setMode(TravelMode.walk);

    expect(map.transitStopMarkers, isEmpty);
  });

  test('selecting another journey redraws its geometry', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.planTransit(origin: origin, destination: destination);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    // Journey 1 draws three lines (walk, ride, walk).
    expect(map.routeLines, hasLength(3));

    controller.selectItinerary(1);

    expect(container.read(routeControllerProvider).selectedItineraryIndex, 1);
    // Journey 2 has four legs, so four lines are drawn.
    expect(map.routeLines, hasLength(4));
  });

  test(
    'opening the detail is a second step, closing returns to the list',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final RouteController controller = container.read(
        routeControllerProvider.notifier,
      );
      await controller.planTransit(origin: origin, destination: destination);
      expect(
        container.read(routeControllerProvider).transitDetailOpen,
        isFalse,
      );

      controller.openTransitDetail(1);

      final RouteState opened = container.read(routeControllerProvider);
      expect(opened.transitDetailOpen, isTrue);
      expect(opened.selectedItineraryIndex, 1);
      expect(opened.selectedItinerary, isNotNull);

      controller.closeTransitDetail();
      expect(
        container.read(routeControllerProvider).transitDetailOpen,
        isFalse,
      );
    },
  );

  test('switching a planned drive route to transit plans a journey', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );

    await controller.plan(destination);
    expect(container.read(routeControllerProvider).mode, TravelMode.drive);
    expect(container.read(routeControllerProvider).routes, isNotEmpty);

    await controller.setMode(TravelMode.transit);

    final RouteState state = container.read(routeControllerProvider);
    expect(state.mode, TravelMode.transit);
    expect(state.routes, isEmpty);
    expect(state.itineraries, isNotEmpty);
  });

  test('a failing planner shows an error state', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        transitRoutingServiceProvider.overrideWithValue(
          _AlwaysFailingTransit(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(routeControllerProvider.notifier)
        .planTransit(origin: origin, destination: destination);

    final RouteState state = container.read(routeControllerProvider);
    expect(state.status, RouteStatus.error);
    expect(state.itineraries, isEmpty);
    expect(state.error, isNotNull);
  });

  test('transit preferences change the request and re-plan', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.planTransit(origin: origin, destination: destination);

    await controller.setTransitPreferences(
      modes: const <TransitMode>{TransitMode.bus},
      fewerTransfers: true,
    );

    final RouteState state = container.read(routeControllerProvider);
    expect(state.transitModes, <TransitMode>{TransitMode.bus});
    expect(state.fewerTransfers, isTrue);
    expect(state.itineraries, isNotEmpty);
  });

  test('toggling a preference group adds then removes its modes', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.planTransit(origin: origin, destination: destination);

    await controller.toggleTransitGroup(TransitModeGroup.train);
    expect(
      container.read(routeControllerProvider).transitModes,
      containsAll(TransitModeGroup.train.modes),
    );

    await controller.toggleTransitGroup(TransitModeGroup.train);
    expect(
      container
          .read(routeControllerProvider)
          .transitModes
          .intersection(TransitModeGroup.train.modes.toSet()),
      isEmpty,
    );
  });

  test('plan() honours the current transit mode', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.planTransit(origin: origin, destination: destination);

    // Planning a new destination while in transit mode must plan a journey,
    // not fall through to the street router.
    await controller.plan(destination);

    final RouteState state = container.read(routeControllerProvider);
    expect(state.mode, TravelMode.transit);
    expect(state.status, RouteStatus.data);
    expect(state.itineraries, isNotEmpty);
  });

  test('leaving transit mode clears the journeys', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.planTransit(origin: origin, destination: destination);

    await controller.setMode(TravelMode.walk);

    final RouteState state = container.read(routeControllerProvider);
    expect(state.mode, TravelMode.walk);
    expect(state.itineraries, isEmpty);
  });
}
