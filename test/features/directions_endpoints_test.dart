import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/features/directions/widgets/directions_endpoint_card.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/route.dart';

/// The floating endpoint card plus the search-style place picker it opens.
void main() {
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Plans a route to the first "coffee" result (Harbour Coffee).
  Future<String> planCoffee(ProviderContainer container) async {
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    await registry.dispatch('route.plan', <String, Object?>{'id': id});
    return id;
  }

  Finder cardText(String text) => find.descendant(
    of: find.byType(DirectionsEndpointCard),
    matching: find.text(text),
  );

  testWidgets('a route shows the floating endpoint card, not the search bar', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);
    await planCoffee(container);
    await tester.pumpAndSettle();

    expect(find.byType(DirectionsEndpointCard), findsOneWidget);
    expect(cardText('Harbour Coffee'), findsOneWidget);
    // The search bar is replaced while directions are open.
    expect(find.text('Search here'), findsNothing);
  });

  testWidgets('tapping a field opens the picker for that endpoint', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);
    await planCoffee(container);
    await tester.pumpAndSettle();

    await tester.tap(cardText('Harbour Coffee'));
    await tester.pumpAndSettle();

    expect(
      container.read(routeControllerProvider).editingEndpoint,
      const RouteEndpointTarget.destination(),
    );
    expect(find.text('Choose on map'), findsOneWidget);
    expect(find.text('Your location'), findsOneWidget);
  });

  testWidgets('searching in the picker fills the endpoint', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);
    await planCoffee(container);
    await tester.pumpAndSettle();

    // Edit the start.
    await tester.tap(cardText('Your location'));
    await tester.pumpAndSettle();
    expect(
      container.read(routeControllerProvider).editingEndpoint,
      const RouteEndpointTarget.origin(),
    );

    await tester.enterText(find.byType(TextField), 'park');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Willow Park'));
    await tester.pumpAndSettle();

    final RouteState state = container.read(routeControllerProvider);
    expect(state.origin?.name, 'Willow Park');
    expect(state.editingEndpoint, isNull);
    // Back on the map with the card visible.
    expect(find.byType(DirectionsEndpointCard), findsOneWidget);
  });

  testWidgets('"Choose on map" arms long-press picking and returns', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);
    await planCoffee(container);
    await tester.pumpAndSettle();

    await tester.tap(cardText('Harbour Coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();

    final RouteState state = container.read(routeControllerProvider);
    expect(state.pickTarget, const RouteEndpointTarget.destination());
    expect(state.editingEndpoint, isNull);
  });

  testWidgets('the overflow menu adds a stop through the picker', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);
    await planCoffee(container);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Route options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add stop'));
    await tester.pumpAndSettle();

    expect(
      container.read(routeControllerProvider).editingEndpoint?.field,
      RouteEndpointField.stop,
    );

    await tester.enterText(find.byType(TextField), 'park');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Willow Park'));
    await tester.pumpAndSettle();

    final RouteState state = container.read(routeControllerProvider);
    expect(state.stops, hasLength(1));
    expect(state.stops.first.name, 'Willow Park');
    // The added stop appears as a row on the card.
    expect(cardText('Willow Park'), findsOneWidget);

    // The ✕ removes the stop; it must not open the stop editor.
    await tester.tap(find.byTooltip('Remove stop'));
    await tester.pumpAndSettle();
    expect(container.read(routeControllerProvider).stops, isEmpty);
    expect(container.read(routeControllerProvider).editingEndpoint, isNull);
    expect(find.text('Choose on map'), findsNothing);
  });
}
