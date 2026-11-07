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

  test(
    'recenterOrOverview recenters a browsed map, else toggles overview',
    () async {
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

      // While tracking, the button toggles the whole-route overview.
      controller.recenterOrOverview();
      expect(container.read(navigationControllerProvider).overview, isTrue);
      expect(
        container.read(navigationControllerProvider).cameraFollows,
        isFalse,
      );

      // From the overview, it goes back to tracking.
      controller.recenterOrOverview();
      expect(container.read(navigationControllerProvider).overview, isFalse);
      expect(
        container.read(navigationControllerProvider).cameraFollows,
        isTrue,
      );

      // After a manual pan it re-centers instead of opening the overview.
      map.emitUserGesture();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(navigationControllerProvider).cameraFollows,
        isFalse,
      );
      controller.recenterOrOverview();
      final NavState state = container.read(navigationControllerProvider);
      expect(state.cameraFollows, isTrue);
      expect(state.overview, isFalse);
    },
  );

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

  test('guidance announces the upcoming maneuver, not the one just passed', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    const double metersPerDegree = 111320;
    const double startLat = 52.5200;
    final Route route = Route(
      legs: <Leg>[
        Leg(
          maneuvers: const <Maneuver>[
            Maneuver(
              instruction: 'Drive north on Main Street',
              type: ManeuverType.depart,
              distanceMeters: 300,
              streetName: 'Main Street',
            ),
            Maneuver(
              instruction: 'Turn left onto Bebelplatz',
              type: ManeuverType.turnLeft,
              distanceMeters: 400,
              streetName: 'Bebelplatz',
            ),
            Maneuver(
              instruction: 'Arrive at your destination',
              type: ManeuverType.arrive,
            ),
          ],
          distanceMeters: 700,
          duration: Duration(minutes: 5),
        ),
      ],
      distanceMeters: 700,
      duration: const Duration(minutes: 5),
      geometry: const <LatLon>[
        LatLon(startLat, 13.4050),
        LatLon(startLat + 900 / metersPerDegree, 13.4050),
      ],
    );

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(route);

    // At the start we are on the departure segment, so the banner announces the
    // left turn ahead (300 m away) rather than the departure we just began.
    NavState state = container.read(navigationControllerProvider);
    expect(state.nextManeuver?.type, ManeuverType.turnLeft);
    expect(state.distanceToNextManeuver, closeTo(300, 5));

    controller.step(meters: 100);
    state = container.read(navigationControllerProvider);
    expect(state.nextManeuver?.type, ManeuverType.turnLeft);
    expect(state.distanceToNextManeuver, closeTo(200, 5));

    // Past the turn, the next thing announced is the arrival.
    controller.step(meters: 300);
    state = container.read(navigationControllerProvider);
    expect(state.nextManeuver?.type, ManeuverType.arrive);
  });
}
