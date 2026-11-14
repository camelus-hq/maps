import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/domain/entities/cycling_options.dart';
import 'package:openmaps/features/directions/screens/directions_sheet.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/route.dart';

void main() {
  Future<ProviderContainer> planCycleRoute() async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    // The default travel mode is Cycle; plan a route in it.
    await registry.dispatch('route.plan', <String, Object?>{'id': id});
    return container;
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DirectionsSheet())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the cycle mode shows the bike options', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await planCycleRoute();
    await pumpSheet(tester, container);

    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('Hybrid'), findsOneWidget);
    expect(find.text('Hills'), findsOneWidget);
    expect(find.text('Avoid bad surfaces'), findsOneWidget);
    expect(find.text('Roads'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Avoid edges'), findsOneWidget);
  });

  testWidgets('picking a bicycle type stores it and follows its speed', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await planCycleRoute();
    await pumpSheet(tester, container);

    await tester.ensureVisible(find.text('Hybrid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hybrid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mountain').last);
    await tester.pumpAndSettle();

    final CyclingOptions cycling = container
        .read(routeControllerProvider)
        .cycling;
    expect(cycling.bicycleType, BicycleType.mountain);
    // A mountain bike's default cruising speed is 16 km/h.
    expect(cycling.effectiveCyclingSpeed, 16);
  });

  testWidgets('the bike options are hidden for other travel modes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await planCycleRoute();
    await pumpSheet(tester, container);
    expect(find.text('Bike'), findsOneWidget);

    await tester.tap(find.text('Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Bike'), findsNothing);
  });
}
