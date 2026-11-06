import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_navigation_notifications.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/navigation_notifications.dart';
import 'package:openmaps/state/ports.dart';

Route _route() {
  const double metersPerDegree = 111320;
  return Route(
    legs: <Leg>[
      Leg(
        maneuvers: const <Maneuver>[
          Maneuver(
            instruction: 'Drive north on Main Street',
            type: ManeuverType.depart,
            distanceMeters: 500,
            streetName: 'Main Street',
          ),
          Maneuver(
            instruction: 'Turn left onto Bebelplatz',
            type: ManeuverType.turnLeft,
            distanceMeters: 500,
            streetName: 'Bebelplatz',
          ),
          Maneuver(
            instruction: 'Arrive at your destination',
            type: ManeuverType.arrive,
          ),
        ],
        distanceMeters: 1000,
        duration: const Duration(minutes: 10),
      ),
    ],
    distanceMeters: 1000,
    duration: const Duration(minutes: 10),
    geometry: <LatLon>[
      const LatLon(52.5200, 13.4050),
      LatLon(52.5200 + 1000 / metersPerDegree, 13.4050),
    ],
  );
}

/// A route whose announced (upcoming) maneuver is [type], 300 m ahead.
Route _routeWithNext(ManeuverType type) {
  const double metersPerDegree = 111320;
  return Route(
    legs: <Leg>[
      Leg(
        maneuvers: <Maneuver>[
          const Maneuver(
            instruction: 'Drive north.',
            type: ManeuverType.depart,
            distanceMeters: 300,
          ),
          Maneuver(
            instruction: 'Next maneuver.',
            type: type,
            distanceMeters: 700,
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
}

void main() {
  late FakeNavigationNotifications notifications;
  late ProviderContainer container;

  setUp(() {
    notifications = FakeNavigationNotifications();
    container = ProviderContainer(
      overrides: <Override>[
        navigationNotificationsProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Builds the bridge (registering its nav listener) before guidance starts.
  void arm() {
    container.read(navigationNoticeProvider);
  }

  test(
    'starting guidance shows an ongoing notification with progress',
    () async {
      arm();
      container.read(navigationControllerProvider.notifier).start(_route());
      await pumpEventQueue();

      expect(notifications.visible, isTrue);
      expect(notifications.title, 'Turn left onto Bebelplatz');
      expect(notifications.body, contains('Arrives'));
      expect(notifications.progress, 0);
      // The status-bar chip shows the upcoming direction (arrow + distance).
      expect(notifications.statusChip, startsWith('← '));
      // The icon is selected by the travel mode (drive).
      expect(notifications.mode, TravelMode.drive);
      expect(notifications.permissionRequests, 1);

      final NavigationNotice notice = container.read(navigationNoticeProvider);
      expect(notice.visible, isTrue);
      expect(notice.progress, 0);
      expect(notice.statusChip, startsWith('← '));
    },
  );

  test('advancing the trip grows the progress bar', () async {
    arm();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_route());
    await pumpEventQueue();

    controller.step(meters: 500);
    await pumpEventQueue();

    expect(notifications.visible, isTrue);
    expect(notifications.progress, 50);
  });

  test('the status chip uses a glyph for every upcoming maneuver', () async {
    arm();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    const List<(ManeuverType, String)> icons = <(ManeuverType, String)>[
      (ManeuverType.depart, '●'),
      (ManeuverType.straight, '↑'),
      (ManeuverType.slightLeft, '↖'),
      (ManeuverType.turnLeft, '←'),
      (ManeuverType.sharpLeft, '↰'),
      (ManeuverType.uTurnLeft, '↶'),
      (ManeuverType.slightRight, '↗'),
      (ManeuverType.turnRight, '→'),
      (ManeuverType.sharpRight, '↱'),
      (ManeuverType.uTurnRight, '↷'),
      (ManeuverType.keepLeft, '⇦'),
      (ManeuverType.keepRight, '⇨'),
      (ManeuverType.rampLeft, '↙'),
      (ManeuverType.rampRight, '↘'),
      (ManeuverType.exitLeft, '⇙'),
      (ManeuverType.exitRight, '⇘'),
      (ManeuverType.merge, '⤒'),
      (ManeuverType.mergeLeft, '⤺'),
      (ManeuverType.mergeRight, '⤻'),
      (ManeuverType.roundabout, '⟳'),
      (ManeuverType.roundaboutExit, '⤴'),
      (ManeuverType.arrive, '⚑'),
      (ManeuverType.unknown, '?'),
    ];

    for (final (ManeuverType type, String icon) in icons) {
      controller.start(_routeWithNext(type));
      await pumpEventQueue();
      expect(notifications.statusChip, startsWith('$icon '), reason: '$type');
      controller.stop();
      await pumpEventQueue();
    }
  });

  test('the notification icon follows the travel mode', () async {
    arm();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );

    controller.start(_route(), mode: TravelMode.cycle);
    await pumpEventQueue();
    expect(notifications.mode, TravelMode.cycle);

    // A mid-route mode change re-skins the icon too.
    controller.setMode(TravelMode.walk);
    await pumpEventQueue();
    expect(notifications.mode, TravelMode.walk);

    controller.stop();
    await pumpEventQueue();
    expect(notifications.mode, isNull);
  });

  test('stopping guidance dismisses the notification', () async {
    arm();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_route());
    await pumpEventQueue();
    expect(notifications.visible, isTrue);

    controller.stop();
    await pumpEventQueue();

    expect(notifications.visible, isFalse);
    expect(container.read(navigationNoticeProvider).visible, isFalse);
  });

  test('arriving dismisses the notification', () async {
    arm();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_route());
    await pumpEventQueue();

    controller.step(meters: 2000);
    await pumpEventQueue();

    expect(
      container.read(navigationControllerProvider).status,
      NavStatus.arrived,
    );
    expect(notifications.visible, isFalse);
  });

  test('the notification Exit action stops guidance', () async {
    arm();
    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(_route());
    await pumpEventQueue();
    expect(
      container.read(navigationControllerProvider).status,
      NavStatus.navigating,
    );

    notifications.tapExit();
    await pumpEventQueue();

    expect(container.read(navigationControllerProvider).status, NavStatus.idle);
    expect(notifications.visible, isFalse);
  });

  test('nav.notification reports the running trip', () async {
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('route.plan', <String, Object?>{'id': first['id']});
    await registry.dispatch('nav.start', const <String, Object?>{});

    final Map<String, Object?> notice = await registry.dispatch(
      'nav.notification',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(notice['visible'], isTrue);
    expect(notice['title'], isA<String>());
    expect(notice['body'], contains('Arrives'));
    expect(notice['progress'], isA<int>());
    expect(notice['statusChip'], isA<String>());
    expect(notice['mode'], isA<String>());

    await registry.dispatch('nav.stop', const <String, Object?>{});
    final Map<String, Object?> stopped = await registry.dispatch(
      'nav.notification',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(stopped['visible'], isFalse);
    expect(stopped['progress'], isNull);
    expect(stopped['statusChip'], isNull);
  });
}
