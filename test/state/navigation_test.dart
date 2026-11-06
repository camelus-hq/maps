import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/result.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';
import 'package:openmaps/state/usecases.dart';

void main() {
  test('simulated guidance advances and arrives', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final Result<List<Route>> result =
        await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        );
    final List<Route> routes = result.valueOrNull ?? const <Route>[];
    expect(routes, isNotEmpty);
    final Route route = routes.first;

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(route, auto: false);

    NavState state = container.read(navigationControllerProvider);
    expect(state.status, NavStatus.navigating);
    expect(state.position, isNotNull);
    expect(state.totalMeters, greaterThan(0));

    final double firstTraveled = state.traveledMeters;
    controller.step(meters: 500);
    state = container.read(navigationControllerProvider);
    expect(state.traveledMeters, greaterThan(firstTraveled));

    for (int i = 0; i < 100 && state.status == NavStatus.navigating; i++) {
      controller.step(meters: 1000);
      state = container.read(navigationControllerProvider);
    }
    expect(state.status, NavStatus.arrived);
    expect(state.remaining, Duration.zero);
  });

  test('a far-off position triggers a reroute', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        )).valueOrNull ??
        const <Route>[];
    expect(routes, isNotEmpty);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(routes.first);

    const LatLon pushed = LatLon(52.6000, 13.6000);
    await controller.handlePosition(const LocationSample(position: pushed));

    final NavState state = container.read(navigationControllerProvider);
    expect(state.status, NavStatus.navigating);
    expect(state.route?.geometry.first.latitude, closeTo(52.6, 1e-6));
  });

  test('stopping during a reroute does not resurrect guidance', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        )).valueOrNull ??
        const <Route>[];
    expect(routes, isNotEmpty);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(routes.first);

    // Kick off a deviation-triggered reroute, then stop before it resolves.
    final Future<void> rerouting = controller.handlePosition(
      const LocationSample(position: LatLon(52.6000, 13.6000)),
    );
    controller.stop();
    await rerouting;

    expect(container.read(navigationControllerProvider).status, NavStatus.idle);
  });

  test('a position at the destination arrives', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        )).valueOrNull ??
        const <Route>[];
    expect(routes, isNotEmpty);
    final Route route = routes.first;

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(route);
    await controller.handlePosition(
      LocationSample(position: route.geometry.last),
    );

    final NavState state = container.read(navigationControllerProvider);
    expect(state.status, NavStatus.arrived);
  });

  test('a user gesture pauses tracking; resume recenters', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        )).valueOrNull ??
        const <Route>[];
    expect(routes, isNotEmpty);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(routes.first);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(container.read(navigationControllerProvider).cameraFollows, isTrue);

    // The user drags the map: the guidance camera stops tracking.
    map.emitUserGesture();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(navigationControllerProvider).cameraFollows, isFalse);

    // A guidance step must leave the browsed camera alone.
    const LatLon browsed = LatLon(48.1, 11.6);
    await map.moveCamera(const Camera(target: browsed, zoom: 12));
    controller.step(meters: 500);
    expect(map.camera.target, browsed);

    // Re-centering resumes tracking on the current position.
    controller.resumeTracking();
    expect(container.read(navigationControllerProvider).cameraFollows, isTrue);
    expect(map.camera.target, isNot(browsed));
  });

  test('setMode re-skins the session without touching the route', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        )).valueOrNull ??
        const <Route>[];
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(routes.first, mode: TravelMode.drive);

    final NavState before = container.read(navigationControllerProvider);
    controller.setMode(TravelMode.walk);
    final NavState after = container.read(navigationControllerProvider);
    expect(after.mode, TravelMode.walk);
    expect(identical(after.route, before.route), isTrue);
    expect(after.totalMeters, before.totalMeters);
    expect(after.status, NavStatus.navigating);

    // Idle sessions keep their (default) mode.
    controller.stop();
    controller.setMode(TravelMode.cycle);
    expect(container.read(navigationControllerProvider).mode, TravelMode.drive);
  });

  test('a reroute redraws the route polyline on the map', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.drive,
        )).valueOrNull ??
        const <Route>[];
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(routes.first);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;

    // A far-off position triggers a reroute from there.
    const LatLon pushed = LatLon(52.6000, 13.6000);
    await controller.handlePosition(const LocationSample(position: pushed));

    // The drawn line now starts at the reroute origin, not the old start.
    expect(map.routeLines, isNotEmpty);
    expect(
      map.routeLines.first.points.first.latitude,
      closeTo(pushed.latitude, 1e-6),
    );
    // The route preview was kept in sync too.
    expect(
      container.read(routeControllerProvider).routes.first.geometry.first,
      pushed,
    );
  });
}
