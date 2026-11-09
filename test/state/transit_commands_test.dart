import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/command_registry.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late CommandRegistry registry;

  setUp(() {
    container = ProviderContainer();
    registry = container.read(commandRegistryProvider);
  });

  tearDown(() => container.dispose());

  Map<String, Object?> point(double lat, double lon) => <String, Object?>{
    'lat': lat,
    'lon': lon,
  };

  test('transit.plan plans a journey and returns the itineraries', () async {
    final List<Object?> result = await registry.dispatch(
      'transit.plan',
      <String, Object?>{
        'origin': point(52.52, 13.4),
        'destination': point(52.5, 13.3),
      },
    ) as List<Object?>;

    expect(result, hasLength(2));
    final Map<String, Object?> first = result.first as Map<String, Object?>;
    expect(first['transfers'], 0);
    expect(first['realtime'], isTrue);
    expect(first['lines'], <String>['M2']);
    final List<Object?> legs = first['legs']! as List<Object?>;
    expect(legs, isNotEmpty);

    final RouteState state = container.read(routeControllerProvider);
    expect(state.mode, TravelMode.transit);
    expect(state.status, RouteStatus.data);
  });

  test('transit.itineraries lists, transit.select picks by index', () async {
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': point(52.52, 13.4),
      'destination': point(52.5, 13.3),
    });

    final List<Object?> list = await registry.dispatch(
      'transit.itineraries',
      const <String, Object?>{},
    ) as List<Object?>;
    expect(list, hasLength(2));

    await registry.dispatch('transit.select', <String, Object?>{'index': 1});
    expect(container.read(routeControllerProvider).selectedItineraryIndex, 1);
  });

  test('transit.time sets the departure time and re-plans', () async {
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': point(52.52, 13.4),
      'destination': point(52.5, 13.3),
    });

    await registry.dispatch('transit.time', <String, Object?>{
      'mode': 'depart',
      'time': '2026-05-01T09:00:00Z',
    });

    final RouteState state = container.read(routeControllerProvider);
    expect(state.transitTimeMode, TransitTimeMode.departAt);
    expect(state.transitTime, DateTime.utc(2026, 5, 1, 9));
  });

  test('transit.pref applies a mode preference', () async {
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': point(52.52, 13.4),
      'destination': point(52.5, 13.3),
    });

    await registry.dispatch('transit.pref', <String, Object?>{
      'modes': <String>['bus'],
      'lessWalking': true,
    });

    final RouteState state = container.read(routeControllerProvider);
    expect(state.transitModes, contains(TransitMode.bus));
    expect(state.lessWalking, isTrue);
  });

  test('route.mode switches to transit', () async {
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': point(52.52, 13.4),
      'destination': point(52.5, 13.3),
    });
    await registry.dispatch('route.mode', <String, Object?>{'mode': 'walk'});

    await registry.dispatch('route.mode', <String, Object?>{'mode': 'transit'});

    final RouteState state = container.read(routeControllerProvider);
    expect(state.mode, TravelMode.transit);
    expect(state.itineraries, isNotEmpty);
  });

  test(
    'transit.detail opens the detail and transit.detail.close returns',
    () async {
      await registry.dispatch('transit.plan', <String, Object?>{
        'origin': point(52.52, 13.4),
        'destination': point(52.5, 13.3),
      });

      final Map<String, Object?> journey = await registry.dispatch(
        'transit.detail',
        <String, Object?>{'index': 1},
      ) as Map<String, Object?>;
      expect(journey['lines'], isNotNull);
      expect(container.read(routeControllerProvider).transitDetailOpen, isTrue);
      expect(container.read(routeControllerProvider).selectedItineraryIndex, 1);

      await registry.dispatch(
        'transit.detail.close',
        const <String, Object?>{},
      );
      expect(
        container.read(routeControllerProvider).transitDetailOpen,
        isFalse,
      );
    },
  );

  test('transit.navigate starts guidance along the journey', () async {
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': point(52.52, 13.4),
      'destination': point(52.5, 13.3),
    });

    final Map<String, Object?> nav = await registry.dispatch(
      'transit.navigate',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(nav['status'], 'navigating');
    // The journey is attached so the transit banner and live timeline can read
    // the current step.
    final Map<String, Object?> progress =
        nav['transit']! as Map<String, Object?>;
    expect(progress['phase'], 'walk');
    expect(progress['legIndex'], 0);
    expect(progress['line'], 'M2');
  });

  test('transit.departures opens a stop board and closes it', () async {
    final Map<String, Object?> board = await registry.dispatch(
      'transit.departures',
      <String, Object?>{'stopId': 'fake:stop-a', 'name': 'North Street'},
    ) as Map<String, Object?>;
    expect(board['status'], 'data');
    expect(board['stopName'], 'North Street');
    final List<Object?> departures = board['departures']! as List<Object?>;
    expect(departures, isNotEmpty);

    await registry.dispatch(
      'transit.departures.close',
      const <String, Object?>{},
    );
    // Bad params are rejected.
    expect(
      () => registry.dispatch('transit.departures', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });

  test('map.transitStops lists the drawn stop circles', () async {
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': point(52.52, 13.4),
      'destination': point(52.5, 13.3),
    });

    final List<Object?> stops = await registry.dispatch(
      'map.transitStops',
      const <String, Object?>{},
    ) as List<Object?>;
    expect(stops, hasLength(3));
    final Map<String, Object?> board = stops
        .cast<Map<String, Object?>>()
        .firstWhere((Map<String, Object?> stop) => stop['emphasis'] == 'board');
    expect(board['board'], isTrue);
    expect(board['lat'], isA<double>());
  });

  test('transit commands reject hostile parameters', () async {
    // Missing endpoints.
    expect(
      () => registry.dispatch('transit.plan', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
    // Unknown time mode.
    expect(
      () => registry.dispatch('transit.time', <String, Object?>{
        'mode': 'whenever',
      }),
      throwsA(isA<CommandException>()),
    );
    // Unknown transit mode name.
    expect(
      () => registry.dispatch('transit.pref', <String, Object?>{
        'modes': <String>['teleporter'],
      }),
      throwsA(isA<CommandException>()),
    );
    // Selecting a journey that does not exist.
    expect(
      () => registry.dispatch('transit.select', <String, Object?>{'index': 9}),
      throwsA(isA<CommandException>()),
    );
    // route.request refuses transit mode (it has its own planner).
    expect(
      () => registry.dispatch('route.request', <String, Object?>{
        'origin': point(52.52, 13.4),
        'destination': point(52.5, 13.3),
        'mode': 'transit',
      }),
      throwsA(isA<CommandException>()),
    );
    // Detail of a journey that does not exist.
    expect(
      () => registry.dispatch('transit.detail', <String, Object?>{'index': 9}),
      throwsA(isA<CommandException>()),
    );
    // Navigating with no journey planned.
    expect(
      () => registry.dispatch('transit.navigate', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });
}
