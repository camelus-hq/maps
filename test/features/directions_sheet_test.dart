import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Route;
import 'package:openmaps/domain/entities/cycling_options.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/routing_service.dart';
import 'package:openmaps/features/common/shimmer.dart';
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
}
