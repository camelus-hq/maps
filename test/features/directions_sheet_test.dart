import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/features/directions/screens/directions_sheet.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/navigation.dart';

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
}
