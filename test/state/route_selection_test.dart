import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/cycling_options.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/route_line.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/routing_service.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

/// A [RoutingService] that returns two visibly different alternatives so the
/// route-alternative selection can be exercised keylessly.
class _TwoRouteService implements RoutingService {
  const _TwoRouteService();

  @override
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
    CyclingOptions? cycling,
  }) async {
    if (waypoints.length < 2) {
      return const <Route>[];
    }
    final LatLon from = waypoints.first;
    final LatLon to = waypoints.last;
    Route line(double bend) => Route(
      legs: const <Leg>[],
      distanceMeters: 1000,
      duration: const Duration(minutes: 5),
      geometry: <LatLon>[
        from,
        LatLon(to.latitude + bend, to.longitude + bend),
        to,
      ],
    );
    return <Route>[line(0), line(0.02)];
  }
}

class _Harness {
  _Harness()
    : container = ProviderContainer(
        overrides: <Override>[
          routingServiceProvider.overrideWithValue(const _TwoRouteService()),
        ],
      );

  final ProviderContainer container;

  Future<void> planRoute() => container
      .read(routeControllerProvider.notifier)
      .plan(const Place(id: 'd', name: 'Dest', position: LatLon(52.53, 13.42)));

  FakeMapService get map =>
      container.read(mapServiceProvider) as FakeMapService;
}

void main() {
  test('the chosen route is drawn last and flagged primary', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.container.dispose);
    await harness.planRoute();

    final List<RouteLine> lines = harness.map.routeLines;
    expect(lines, hasLength(2));
    // The selected route is the last line (drawn on top) and carries the
    // emphasis; alternatives are thinner.
    final RouteLine selected = lines.last;
    expect(selected.primary, isTrue);
    expect(selected.width, greaterThan(lines.first.width));
    expect(lines.first.primary, isFalse);
  });

  test('tapping an alternative line on the map switches to it without moving '
      'the camera', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.container.dispose);
    await harness.planRoute();

    final List<Route> routes = harness.container
        .read(routeControllerProvider)
        .routes;
    final Camera before = harness.map.camera;

    // Tap exactly on the second alternative's geometry.
    harness.map.emitTap(routes[1].geometry[1]);
    await Future<void>.delayed(Duration.zero);

    expect(harness.container.read(routeControllerProvider).selectedIndex, 1);
    final RouteLine primary = harness.map.routeLines.singleWhere(
      (RouteLine line) => line.primary,
    );
    expect(primary.points, routes[1].geometry);
    // The camera stays where it was — a map tap is a highlight, not a re-fit.
    expect(harness.map.camera.zoom, before.zoom);
    expect(harness.map.camera.target, before.target);
  });

  test('a tap far from every route leaves the selection unchanged', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.container.dispose);
    await harness.planRoute();

    harness.map.emitTap(const LatLon(48.0, 11.0));
    await Future<void>.delayed(Duration.zero);

    expect(harness.container.read(routeControllerProvider).selectedIndex, 0);
    expect(harness.map.routeLines, hasLength(2));
  });
}
