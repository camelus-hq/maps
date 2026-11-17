import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_osm_place_source.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/features/map_home/screens/map_home_screen.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';
import 'package:openmaps/state/search.dart';

/// End-to-end check of the URL mirror: selecting a place on the map writes the
/// `/place/<osm>` route, and the back gesture closes it again.
void main() {
  const Place osmPlace = Place(
    id: 'way/159230368',
    name: 'The Place',
    position: LatLon(52.5, 13.4),
  );

  testWidgets('opening a place reflects /place/<osm> in the URL', (
    WidgetTester tester,
  ) async {
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/159230368', osmPlace);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[osmPlaceSourceProvider.overrideWithValue(osm)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(MapHomeScreen)),
    );

    container.read(selectedPlaceProvider.notifier).select(osmPlace);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/place/way/159230368');

    // The back gesture closes the place (and clears the selection).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(selectedPlaceProvider), isNull);
    expect(router.state.uri.path, '/');
  });

  testWidgets('closing a station sheet never writes a provider mid-build', (
    WidgetTester tester,
  ) async {
    // Regression: closing a place whose overlay route is on the stack makes the
    // URL mirror `go('/')`, which drops the page and used to run its
    // `onPopInvoked` — clearing `selectedPlaceProvider` — from
    // `NavigatorState.didUpdateWidget`, throwing Riverpod's "Tried to modify a
    // provider while the widget tree was building" (reported from the device
    // when closing a public-transport stop).
    const Place station = Place(
      id: 'way/123456',
      name: 'Central Station',
      position: LatLon(52.525, 13.415),
      category: 'rail',
    );
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/123456', station);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[osmPlaceSourceProvider.overrideWithValue(osm)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(MapHomeScreen)),
    );

    container.read(selectedPlaceProvider.notifier).select(station);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/place/way/123456');

    // Close the sheet like the ✕ button does.
    container.read(selectedPlaceProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.state.uri.path, '/');
  });

  testWidgets('a cold-start deep link opens the place from the URL', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/place/way/159230368';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/159230368', osmPlace);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[osmPlaceSourceProvider.overrideWithValue(osm)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(selectedPlaceProvider)?.id, 'way/159230368');
  });

  testWidgets('planning a route reflects /directions with mode and stops', (
    WidgetTester tester,
  ) async {
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/159230368', osmPlace);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[osmPlaceSourceProvider.overrideWithValue(osm)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(MapHomeScreen)),
    );

    await container
        .read(routeControllerProvider.notifier)
        .planRoute(
          destination: osmPlace,
          stops: const <Place>[
            Place(id: 'stop-1', name: 'Stop', position: LatLon(52.51, 13.41)),
          ],
          mode: TravelMode.drive,
        );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/directions');
    expect(router.state.uri.queryParameters['mode'], 'drive');
    expect(router.state.uri.queryParameters['destination'], 'way/159230368');
    expect(router.state.uri.queryParametersAll['stop'], hasLength(1));
  });

  testWidgets('typing a query reflects /search?q= (debounced)', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(MapHomeScreen)),
    );

    unawaited(router.push('/search'));
    await tester.pumpAndSettle();
    container.read(searchControllerProvider.notifier).queryChanged('coffee');
    // The search debounce (300 ms) and the URL debounce (350 ms) both have to
    // elapse before the query lands in the URL.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/search');
    expect(router.state.uri.queryParameters['q'], 'coffee');
  });

  testWidgets('selecting a search result reflects the place route on return', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(MapHomeScreen)),
    );

    unawaited(router.push('/search'));
    await tester.pumpAndSettle();
    await container
        .read(searchControllerProvider.notifier)
        .submitText('coffee');
    await tester.pumpAndSettle();

    // The search screen selects the result and pops back to the map.
    final String id = container.read(searchControllerProvider).results.first.id;
    container
        .read(selectedPlaceProvider.notifier)
        .select(container.read(searchControllerProvider).results.first);
    router.pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/place/$id');
  });
}
