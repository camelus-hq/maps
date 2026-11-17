import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Route;
import 'package:openmaps/core/theme/app_spacing.dart';
import 'package:openmaps/domain/entities/cycling_options.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/routing_service.dart';
import 'package:openmaps/features/common/shimmer.dart';
import 'package:openmaps/features/design/atoms/play_chip.dart';
import 'package:openmaps/features/directions/screens/directions_sheet.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

/// A routing service whose single request never resolves until the test says
/// so, keeping the sheet in its loading state.
class _PendingRoutingService implements RoutingService {
  final Completer<List<Route>> completer = Completer<List<Route>>();

  @override
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
    CyclingOptions? cycling,
  }) => completer.future;
}

/// A routing service that always answers with three alternatives, enough for
/// the chip row to wrap onto a second line at phone width.
class _ThreeRouteService implements RoutingService {
  @override
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
    CyclingOptions? cycling,
  }) async => const <Route>[
    Route(
      legs: <Leg>[],
      distanceMeters: 7100,
      duration: Duration(minutes: 26),
      geometry: <LatLon>[LatLon(52.52, 13.405), LatLon(52.521, 13.4075)],
    ),
    Route(
      legs: <Leg>[],
      distanceMeters: 7300,
      duration: Duration(minutes: 26),
      geometry: <LatLon>[LatLon(52.52, 13.405), LatLon(52.522, 13.408)],
    ),
    Route(
      legs: <Leg>[],
      distanceMeters: 8600,
      duration: Duration(minutes: 34),
      geometry: <LatLon>[LatLon(52.52, 13.405), LatLon(52.523, 13.409)],
    ),
  ];
}

void main() {
  testWidgets('directions sheet shows a Start button that begins guidance', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);

    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    await registry.dispatch('route.plan', <String, Object?>{'id': id});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DirectionsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    // The old list-row affordance is gone.
    expect(find.text('Simulated guidance'), findsNothing);

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(
      container.read(navigationControllerProvider).status,
      NavStatus.navigating,
    );
  });

  testWidgets('directions sheet shimmers while a route is being planned', (
    WidgetTester tester,
  ) async {
    final _PendingRoutingService routing = _PendingRoutingService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[routingServiceProvider.overrideWithValue(routing)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DirectionsSheet())),
      ),
    );

    const Place destination = Place(
      id: 'coffee',
      name: 'Coffee',
      position: LatLon(52.521, 13.4075),
    );
    unawaited(
      container
          .read(routeControllerProvider.notifier)
          .plan(destination, suggestMode: true),
    );
    // Let the location lookup and the loading state land.
    await tester.pump();
    await tester.pump();

    expect(container.read(routeControllerProvider).status, RouteStatus.loading);
    expect(find.byType(Shimmer), findsOneWidget);

    // The route lands and the skeleton gives way to the real steps.
    routing.completer.complete(<Route>[
      const Route(
        legs: <Leg>[],
        distanceMeters: 1200,
        duration: Duration(minutes: 6),
        geometry: <LatLon>[LatLon(52.52, 13.405), LatLon(52.521, 13.4075)],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(Shimmer), findsNothing);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('route alternatives that wrap keep a vertical gap', (
    WidgetTester tester,
  ) async {
    // A phone-width sheet, so three route chips cannot fit on one line.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        routingServiceProvider.overrideWithValue(_ThreeRouteService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DirectionsSheet())),
      ),
    );

    const Place destination = Place(
      id: 'coffee',
      name: 'Coffee',
      position: LatLon(52.521, 13.4075),
    );
    unawaited(
      container
          .read(routeControllerProvider.notifier)
          .plan(destination, suggestMode: true),
    );
    await tester.pumpAndSettle();

    final Finder first = find.widgetWithText(PlayChip, 'Route 1 · 26 min');
    final Finder second = find.widgetWithText(PlayChip, 'Route 2 · 26 min');
    final Finder third = find.widgetWithText(PlayChip, 'Route 3 · 34 min');
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(third, findsOneWidget);

    final Rect firstRect = tester.getRect(first);
    final Rect secondRect = tester.getRect(second);
    final Rect thirdRect = tester.getRect(third);

    // The chips wrap onto more than one line at this width (in the widget-test
    // font each glyph is square, so the rows may be one chip deep).
    final List<Rect> rects = <Rect>[firstRect, secondRect, thirdRect];
    final List<double> tops = rects.map((Rect r) => r.top).toSet().toList()
      ..sort();
    expect(tops.length, greaterThanOrEqualTo(2));

    // Every wrapped row sits a full run-spacing below the previous row's bottom
    // edge, never touching it.
    for (int i = 1; i < tops.length; i++) {
      final double previousBottom = rects
          .where((Rect r) => r.top == tops[i - 1])
          .map((Rect r) => r.bottom)
          .reduce((double a, double b) => a > b ? a : b);
      expect(
        tops[i] - previousBottom,
        moreOrLessEquals(AppSpacing.sm, epsilon: 0.5),
      );
    }
  });
}
