import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/result.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/transit_routing_service.dart';
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

  test(
    'a reroute keeps the trip distance and clock from the real start',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final List<Route> routes =
          (await container.read(requestRouteProvider)(
            waypoints: <LatLon>[
              const LatLon(52.5200, 13.4050),
              const LatLon(52.5300, 13.4200),
            ],
            mode: TravelMode.cycle,
          )).valueOrNull ??
          const <Route>[];
      expect(routes, isNotEmpty);

      final NavigationController controller = container.read(
        navigationControllerProvider.notifier,
      );
      controller.start(routes.first, mode: TravelMode.cycle);
      final DateTime? startedAt = container
          .read(navigationControllerProvider)
          .startedAt;
      expect(startedAt, isNotNull);

      controller.step(meters: 400);
      final double covered = container
          .read(navigationControllerProvider)
          .tripTraveledMeters;
      expect(covered, greaterThan(0));

      // A far-off fix reroutes from there, replacing the route.
      await controller.handlePosition(
        const LocationSample(position: LatLon(52.6000, 13.6000)),
      );

      final NavState after = container.read(navigationControllerProvider);
      expect(after.status, NavStatus.navigating);
      // The current route restarted at the fix...
      expect(after.traveledMeters, 0);
      // ...but the trip statistics carried over from the actual start.
      expect(after.startedAt, startedAt);
      expect(after.tripTraveledMeters, closeTo(covered, 1e-6));
    },
  );

  test('the travelled path trail is drawn and survives a reroute', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Route> routes =
        (await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.cycle,
        )).valueOrNull ??
        const <Route>[];
    expect(routes, isNotEmpty);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(routes.first, mode: TravelMode.cycle);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;

    controller.step(meters: 400);
    expect(map.traveledPath.length, greaterThanOrEqualTo(2));
    final LatLon start = map.traveledPath.first;

    // The reroute replaces the drawn route, but the covered path is kept.
    await controller.handlePosition(
      const LocationSample(position: LatLon(52.6000, 13.6000)),
    );
    expect(map.traveledPath.length, greaterThanOrEqualTo(2));
    expect(map.traveledPath.first, start);

    // Ending the trip clears the trail.
    controller.stop();
    expect(map.traveledPath, isEmpty);
  });

  test(
    'a fix between vertices moves the travelled distance smoothly',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      const double metersPerDegree = 111320;
      final Route route = Route(
        legs: <Leg>[
          Leg(
            maneuvers: const <Maneuver>[
              Maneuver(
                instruction: 'Ride north',
                type: ManeuverType.depart,
                distanceMeters: 1000,
              ),
            ],
            distanceMeters: 1000,
            duration: const Duration(minutes: 5),
          ),
        ],
        distanceMeters: 1000,
        duration: const Duration(minutes: 5),
        geometry: <LatLon>[
          const LatLon(52.5200, 13.4050),
          LatLon(52.5200 + 1000 / metersPerDegree, 13.4050),
        ],
      );

      final NavigationController controller = container.read(
        navigationControllerProvider.notifier,
      );
      controller.start(route);

      // A fix halfway along the single segment, offset ~20 m to the side (still
      // on-route): the travelled distance must advance between the vertices
      // instead of snapping to an endpoint.
      final LatLon offMid = LatLon(52.5200 + 500 / metersPerDegree, 13.4053);
      await controller.handlePosition(LocationSample(position: offMid));

      final NavState state = container.read(navigationControllerProvider);
      expect(state.status, NavStatus.navigating);
      expect(state.traveledMeters, closeTo(500, 15));
    },
  );

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

  test('transit guidance keeps the camera flat and detects boarding', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final TransitItinerary itinerary = _transitJourney();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(
      itinerary.toRoute(),
      mode: TravelMode.transit,
      transit: itinerary,
    );
    // Flush the initial fly-to.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Transit guidance keeps the camera flat and north-up.
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.camera.tilt, 0);
    expect(map.camera.bearing, 0);

    expect(
      container.read(navigationControllerProvider).transitProgress?.phase,
      TransitPhase.walk,
    );

    // A live fix on the ride's geometry reads as "on board".
    final List<LatLon> ride = itinerary.legs[1].geometry;
    await controller.handlePosition(
      LocationSample(position: ride[ride.length ~/ 2], bearing: 90),
    );
    final TransitProgress progress = container
        .read(navigationControllerProvider)
        .transitProgress!;
    expect(progress.phase, TransitPhase.ride);
    expect(progress.legIndex, 1);

    // On board, the whole ride section is framed (not a close-up of the fix).
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final LatLon center = LatLon(
      (ride.first.latitude + ride.last.latitude) / 2,
      (ride.first.longitude + ride.last.longitude) / 2,
    );
    expect(map.camera.target.latitude, closeTo(center.latitude, 1e-6));
    expect(map.camera.target.longitude, closeTo(center.longitude, 1e-6));
  });

  test('a live schedule mismatch re-plans the journey', () async {
    final _ReplanTransit service = _ReplanTransit('REPLAN');
    final ProviderContainer container = ProviderContainer(
      overrides: [transitRoutingServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    // A stale plan: the ride should already be over, but the position is still
    // at its start — the traveller is on a different (earlier) train.
    final TransitItinerary stale = _transitJourney(
      base: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(
      stale.toRoute(),
      mode: TravelMode.transit,
      transit: stale,
      live: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final LatLon ridePoint = stale.legs[1].geometry[4];
    for (int i = 0; i < 3; i++) {
      await controller.handlePosition(LocationSample(position: ridePoint));
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(service.plans, 1);
    final NavState state = container.read(navigationControllerProvider);
    expect(state.status, NavStatus.navigating);
    expect(state.transit?.legs[1].routeShortName, 'REPLAN');
    // The sheet's remaining time is the new journey's schedule, not the old one.
    expect(state.remaining.inMinutes, inInclusiveRange(18, 20));
  });

  test('a schedule mismatch without live positions never re-plans', () async {
    final _ReplanTransit service = _ReplanTransit('REPLAN');
    final ProviderContainer container = ProviderContainer(
      overrides: [transitRoutingServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final TransitItinerary stale = _transitJourney(
      base: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(stale.toRoute(), mode: TravelMode.transit, transit: stale);

    final LatLon rideStart = stale.legs[1].geometry.first;
    for (int i = 0; i < 5; i++) {
      await controller.handlePosition(LocationSample(position: rideStart));
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(service.plans, 0);
  });
}

TransitItinerary _transitJourney({DateTime? base, String tag = 'U2'}) {
  final DateTime start = base ?? DateTime.utc(2026, 1, 1, 9);
  List<LatLon> line(double aLat, double aLon, double bLat, double bLon) =>
      <LatLon>[
        for (int i = 0; i <= 8; i++)
          LatLon(aLat + (bLat - aLat) * i / 8, aLon + (bLon - aLon) * i / 8),
      ];
  return TransitItinerary(
    startTime: start,
    endTime: start.add(const Duration(minutes: 20)),
    legs: <TransitLeg>[
      TransitLeg(
        mode: TransitMode.walk,
        from: const TransitStop(name: 'Start', position: LatLon(52.50, 13.40)),
        to: const TransitStop(
          name: 'Stop A',
          id: 'a',
          position: LatLon(52.51, 13.40),
        ),
        startTime: start,
        endTime: start.add(const Duration(minutes: 5)),
        duration: const Duration(minutes: 5),
        geometry: line(52.50, 13.40, 52.51, 13.40),
      ),
      TransitLeg(
        mode: TransitMode.subway,
        from: const TransitStop(
          name: 'Stop A',
          id: 'a',
          position: LatLon(52.51, 13.40),
        ),
        to: const TransitStop(
          name: 'Stop B',
          id: 'b',
          position: LatLon(52.55, 13.42),
        ),
        startTime: start.add(const Duration(minutes: 6)),
        endTime: start.add(const Duration(minutes: 20)),
        duration: const Duration(minutes: 14),
        routeShortName: tag,
        geometry: line(52.51, 13.40, 52.55, 13.42),
      ),
    ],
  );
}

/// A transit planner that always returns one fresh journey tagged [tag].
class _ReplanTransit implements TransitRoutingService {
  _ReplanTransit(this.tag);

  final String tag;
  int plans = 0;

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async {
    plans++;
    return <TransitItinerary>[_transitJourney(base: DateTime.now(), tag: tag)];
  }

  @override
  Future<List<TransitStopDeparture>> departures(
    TransitDeparturesQuery query,
  ) async => const <TransitStopDeparture>[];
}
