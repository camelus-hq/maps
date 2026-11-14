import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/features/map_home/screens/map_home_screen.dart';
import 'package:openmaps/state/commands/commands_provider.dart';

void main() {
  testWidgets('shows "Search this area" after panning away from results', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MapHomeScreen()),
      ),
    );

    await registry.dispatch('search.query', <String, Object?>{
      'text': 'coffee',
    });
    await tester.pump(); // let the results-fit callback record the camera
    await registry.dispatch('map.camera.set', <String, Object?>{
      'lat': 0,
      'lon': 0,
      'zoom': 4,
    });
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Search this area'), findsOneWidget);
  });
}
