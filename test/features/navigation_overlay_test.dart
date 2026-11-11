import 'dart:async';

import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/elevation.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/features/directions/widgets/maneuver_glyph.dart';
import 'package:openmaps/features/navigation/nav_style.dart';
import 'package:openmaps/features/navigation/widgets/car_nav_bottom_sheet.dart';
import 'package:openmaps/features/navigation/widgets/cycle_gradient_profile.dart';
import 'package:openmaps/features/navigation/widgets/cycle_nav_bottom_sheet.dart';
import 'package:openmaps/features/navigation/widgets/cycle_navigation_view.dart';
import 'package:openmaps/features/navigation/widgets/drive_navigation_view.dart';
import 'package:openmaps/features/navigation/widgets/nav_sheet.dart';
import 'package:openmaps/features/navigation/widgets/nav_widgets.dart';
import 'package:openmaps/features/navigation/widgets/transit_nav_bottom_sheet.dart';
import 'package:openmaps/features/navigation/widgets/walk_nav_bottom_sheet.dart';
import 'package:openmaps/features/navigation/widgets/walk_navigation_view.dart';
import 'package:openmaps/state/location.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/ports.dart';

class _ControllableLocationService implements LocationService {
  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();
  LocationSample? _last;

  @override
  Future<LocationSample?> lastKnown() async => _last;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  @override
  Stream<bool> availabilityStream() => const Stream<bool>.empty();

  void emit(LocationSample sample) {
    _last = sample;
    _controller.add(sample);
  }

  void fail() => _controller.addError(StateError('gps'));

  Future<void> dispose() => _controller.close();
}

Route _turnRoute({
  double distanceMeters = 200,
  List<LaneGuidance> lanes = const <LaneGuidance>[],
}) {
  return Route(
    legs: <Leg>[
      Leg(
        maneuvers: <Maneuver>[
          Maneuver(
            instruction: 'Turn left onto Bebelplatz',
            type: ManeuverType.turnLeft,
            distanceMeters: distanceMeters,
            streetName: 'Bebelplatz',
            lanes: lanes,
          ),
        ],
        distanceMeters: distanceMeters,
        duration: const Duration(minutes: 6),
      ),
    ],
    distanceMeters: distanceMeters,
    duration: const Duration(minutes: 6),
    geometry: const <LatLon>[
      LatLon(52.5190, 13.4040),
      LatLon(52.5210, 13.4070),
      LatLon(52.5230, 13.4100),
    ],
  );
}

/// A straight ~1.43 km route, for exercising kilometre-precision readouts.
Route _longRoute({double meters = 1430}) {
  const double metersPerDegree = 111320;
  return Route(
    legs: <Leg>[
      Leg(
        maneuvers: <Maneuver>[
          Maneuver(
            instruction: 'Ride on',
            type: ManeuverType.depart,
            distanceMeters: meters,
          ),
        ],
        distanceMeters: meters,
        duration: const Duration(minutes: 6),
      ),
    ],
    distanceMeters: meters,
    duration: const Duration(minutes: 6),
    geometry: <LatLon>[
      const LatLon(52.5200, 13.4050),
      LatLon(52.5200 + meters / metersPerDegree, 13.4050),
    ],
  );
}

/// A route whose elevation profile climbs steeply right from the start, so the
/// cycling sheet's "climb ahead" auto-switch fires.
Route _hillRoute() {
  return Route(
    legs: <Leg>[
      Leg(
        maneuvers: <Maneuver>[
          Maneuver(
            instruction: 'Climb the hill',
            type: ManeuverType.depart,
            distanceMeters: 1000,
          ),
        ],
        distanceMeters: 1000,
        duration: const Duration(minutes: 4),
      ),
    ],
    distanceMeters: 1000,
    duration: const Duration(minutes: 4),
    geometry: const <LatLon>[
      LatLon(52.4874, 13.3975),
      LatLon(52.4880, 13.4035),
      LatLon(52.4965, 13.4350),
    ],
    elevation: const ElevationProfile(<ElevationPoint>[
      ElevationPoint(distanceMeters: 0, elevationMeters: 40),
      ElevationPoint(distanceMeters: 200, elevationMeters: 90),
      ElevationPoint(distanceMeters: 1000, elevationMeters: 95),
    ]),
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const OpenMapsApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'drive guidance shows the banner, lanes, speed chip and ETA card',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);

      container
          .read(navigationControllerProvider.notifier)
          .start(
            _turnRoute(
              lanes: const <LaneGuidance>[
                LaneGuidance(
                  active: true,
                  indications: <LaneIndication>[LaneIndication.left],
                ),
                LaneGuidance(
                  indications: <LaneIndication>[
                    LaneIndication.straight,
                    LaneIndication.right,
                  ],
                ),
              ],
            ),
            mode: TravelMode.drive,
          );
      await tester.pump();

      expect(find.byType(DriveNavigationView), findsOneWidget);
      expect(find.byType(NavBanner), findsOneWidget);
      expect(find.byType(NavLaneStrip), findsOneWidget);
      expect(find.byType(NavSpeedChip), findsOneWidget);
      expect(find.byType(CarNavBottomSheet), findsOneWidget);
      // Distance + street on the banner.
      expect(find.text('Bebelplatz'), findsOneWidget);
      expect(find.text('200 m'), findsOneWidget);
    },
  );

  testWidgets('a manual map pan during guidance shows the Re-center pill', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    container
        .read(navigationControllerProvider.notifier)
        .start(_turnRoute(), mode: TravelMode.drive);
    await tester.pumpAndSettle();

    // While the camera tracks the position there is no floating pill.
    expect(find.byType(NavRecenterButton), findsNothing);

    // The user pans the map: tracking pauses and the pill appears, above the
    // ETA sheet and in the bottom half of the screen.
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    map.emitUserGesture();
    await tester.pumpAndSettle();

    expect(container.read(navigationControllerProvider).cameraFollows, isFalse);
    final Finder pill = find.byType(NavRecenterButton);
    expect(pill, findsOneWidget);
    expect(
      find.descendant(of: pill, matching: find.text('Re-center')),
      findsOneWidget,
    );
    // Floats above the trip sheet's header, i.e. above the resting sheet.
    expect(
      tester.getBottomLeft(pill).dy,
      lessThan(tester.getTopLeft(find.byType(NavEtaHeader)).dy),
    );

    // Tapping it re-centers, resumes tracking and hides the pill.
    await tester.tap(pill);
    await tester.pumpAndSettle();
    expect(container.read(navigationControllerProvider).cameraFollows, isTrue);
    expect(find.byType(NavRecenterButton), findsNothing);
  });

  testWidgets('switching mode re-skins the same session', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_turnRoute(), mode: TravelMode.drive);
    await tester.pump();
    expect(find.byType(DriveNavigationView), findsOneWidget);

    controller.setMode(TravelMode.walk);
    await tester.pumpAndSettle();

    expect(find.byType(WalkNavigationView), findsOneWidget);
    expect(find.byType(DriveNavigationView), findsNothing);
    // Walking has no lane guidance or speed chip.
    expect(find.byType(NavLaneStrip), findsNothing);
    expect(find.byType(NavSpeedChip), findsNothing);
  });

  testWidgets('a lost GPS signal is called out in the guidance card', (
    WidgetTester tester,
  ) async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });
    await _pumpApp(tester, container);

    container
        .read(navigationControllerProvider.notifier)
        .start(_turnRoute(), mode: TravelMode.drive);
    await tester.pump();

    location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
    await tester.pump();
    location.fail();
    await tester.pump();
    await tester.pump();

    expect(container.read(locationTrackerProvider).lost, isTrue);
    expect(container.read(locationTrackerProvider).hasFix, isTrue);
    expect(find.byType(CarNavBottomSheet), findsOneWidget);
    expect(find.text('Location unavailable'), findsOneWidget);
  });

  testWidgets('the navigation sheet expands to reveal the trip options', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    container
        .read(navigationControllerProvider.notifier)
        .start(_turnRoute(), mode: TravelMode.drive);
    await tester.pump();

    final Finder handle = find.byType(NavEtaHeader);
    expect(handle, findsOneWidget);
    final double before = tester.getTopLeft(handle).dy;

    await tester.drag(handle, const Offset(0, -300), warnIfMissed: false);
    await tester.pumpAndSettle();

    // The sheet grew upwards, revealing the trip options.
    expect(tester.getTopLeft(handle).dy, lessThan(before));
    expect(find.text('Show traffic on map'), findsOneWidget);
    expect(find.text('Show satellite map'), findsOneWidget);
  });

  testWidgets('the in-navigation directions list uses maneuver glyphs', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    container
        .read(navigationControllerProvider.notifier)
        .start(_turnRoute(), mode: TravelMode.drive);
    await tester.pump();

    // Reveal the trip options, then open the step list.
    await tester.drag(
      find.byType(NavEtaHeader),
      const Offset(0, -300),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Directions'));
    await tester.pumpAndSettle();

    // Each step carries its own maneuver glyph (it used to be a single
    // hardcoded right-turn icon for every row).
    final Finder glyphs = find.descendant(
      of: find.byType(ListTile),
      matching: find.byType(ManeuverGlyph),
    );
    expect(glyphs, findsOneWidget);
    expect(tester.widget<ManeuverGlyph>(glyphs).type, ManeuverType.turnLeft);
  });

  test('NavStyle urgency thresholds differ per mode', () {
    final NavStyle drive = NavStyle.forMode(TravelMode.drive);
    expect(drive.urgency(500), NavUrgency.none);
    expect(drive.urgency(200), NavUrgency.soon);
    expect(drive.urgency(40), NavUrgency.now);

    final NavStyle walk = NavStyle.forMode(TravelMode.walk);
    expect(walk.urgency(200), NavUrgency.none);
    expect(walk.urgency(40), NavUrgency.soon);
    expect(walk.urgency(10), NavUrgency.now);
    expect(walk.showSpeed, isFalse);
  });

  test('cycling guidance drops lane guidance but the car keeps it', () {
    expect(NavStyle.forMode(TravelMode.cycle).showLanes, isFalse);
    expect(NavStyle.forMode(TravelMode.drive).showLanes, isTrue);
  });

  testWidgets('cycling drops lanes and leads with the ride stats sheet', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    container
        .read(navigationControllerProvider.notifier)
        .start(
          _turnRoute(
            lanes: const <LaneGuidance>[
              LaneGuidance(
                active: true,
                indications: <LaneIndication>[LaneIndication.left],
              ),
            ],
          ),
          mode: TravelMode.cycle,
        );
    await tester.pump();

    expect(find.byType(CycleNavigationView), findsOneWidget);
    // A bicycle is not bound to road lanes.
    expect(find.byType(NavLaneStrip), findsNothing);
    // The rider's speed lives in the sheet, not a floating chip.
    expect(find.byType(NavSpeedChip), findsNothing);
    expect(find.byType(CycleNavBottomSheet), findsOneWidget);
    // The first stats page.
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('To end'), findsOneWidget);
    expect(find.text('Average speed'), findsOneWidget);
  });

  testWidgets('walk/cycle distances keep a second decimal; drive keeps one', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_longRoute(), mode: TravelMode.cycle);
    await tester.pump();

    // 1430 m reads as 1.43 km in the ETA header for cycling...
    expect(find.textContaining('1.43 km'), findsWidgets);

    // ...but driving keeps the shorter one-decimal form.
    controller.setMode(TravelMode.drive);
    await tester.pumpAndSettle();
    expect(find.textContaining('1.43 km'), findsNothing);
    expect(find.textContaining('1.4 km'), findsWidgets);
  });

  testWidgets('the cycling ride stats swipe horizontally through pages', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    container
        .read(navigationControllerProvider.notifier)
        .start(_turnRoute(), mode: TravelMode.cycle);
    await tester.pump();

    expect(find.text('Average speed'), findsOneWidget);
    expect(find.text('Time left'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    // The second stats page.
    expect(find.text('Elapsed'), findsOneWidget);
    expect(find.text('Time left'), findsOneWidget);
  });

  testWidgets(
    'the cycling sheet expands to the trip options and shrinks back',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);

      container
          .read(navigationControllerProvider.notifier)
          .start(_turnRoute(), mode: TravelMode.cycle);
      await tester.pump();

      final Finder handle = find.byType(NavEtaHeader);
      final double resting = tester.getTopLeft(handle).dy;

      // Expanding reveals the shared trip options.
      await tester.drag(handle, const Offset(0, -350), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(handle).dy, lessThan(resting));
      expect(find.text('Show traffic on map'), findsOneWidget);

      // Shrinking past the default snaps to the bare ETA header.
      await tester.drag(
        find.byType(NavEtaHeader),
        const Offset(0, 700),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(NavEtaHeader)).dy,
        greaterThan(resting),
      );
    },
  );

  testWidgets('walking and transit each have their own sheet', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_turnRoute(), mode: TravelMode.walk);
    await tester.pump();
    expect(find.byType(WalkNavBottomSheet), findsOneWidget);
    expect(find.text('Time left'), findsOneWidget);

    controller.setMode(TravelMode.transit);
    await tester.pumpAndSettle();
    expect(find.byType(TransitNavBottomSheet), findsOneWidget);
    expect(find.textContaining('Public transport'), findsOneWidget);
  });

  testWidgets('the cycling gradient page shows only when the route has '
      'elevation', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    // No elevation → no gradient page; the board has just the two stat pages.
    container
        .read(navigationControllerProvider.notifier)
        .start(_turnRoute(), mode: TravelMode.cycle);
    await tester.pump();
    expect(find.byType(CycleGradientProfile), findsNothing);
    expect(find.byType(NavPageDots), findsOneWidget);

    // With elevation the gradient page exists (last page).
    container.read(navigationControllerProvider.notifier).stop();
    container
        .read(navigationControllerProvider.notifier)
        .start(_hillRoute(), mode: TravelMode.cycle);
    await tester.pump();
    await tester.fling(find.byType(PageView), const Offset(-320, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-320, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(CycleGradientProfile), findsOneWidget);
  });

  testWidgets('the cycling sheet slides to the gradient page on a climb', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_hillRoute(), mode: TravelMode.cycle);
    await tester.pumpAndSettle();

    // The first page is the ride stats, not the gradient.
    expect(find.text('Average speed'), findsOneWidget);
    expect(find.byType(CycleGradientProfile), findsNothing);

    // A position update (a steep climb is ahead) auto-switches to it.
    controller.step(meters: 5);
    await tester.pumpAndSettle();

    expect(find.byType(CycleGradientProfile), findsOneWidget);
    expect(find.text('Average speed'), findsNothing);
  });
}
