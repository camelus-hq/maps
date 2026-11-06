import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/features/navigation/nav_style.dart';
import 'package:openmaps/features/navigation/widgets/drive_navigation_view.dart';
import 'package:openmaps/features/navigation/widgets/nav_bottom_sheet.dart';
import 'package:openmaps/features/navigation/widgets/nav_widgets.dart';
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
      expect(find.byType(NavBottomSheet), findsOneWidget);
      // Distance + street on the banner.
      expect(find.text('Bebelplatz'), findsOneWidget);
      expect(find.text('200 m'), findsOneWidget);
    },
  );

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
    expect(find.byType(NavBottomSheet), findsOneWidget);
    expect(find.text('Searching for GPS…'), findsOneWidget);
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
}
