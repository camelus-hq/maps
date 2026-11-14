import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/app/app.dart';

/// Golden for the keyless map-home shell.
///
/// The real Mapbox surface is a platform view and cannot be a golden, so this
/// renders the placeholder path (no Mapbox token) — the shell chrome
/// (search pill, category chips, controls, draggable sheet) is what we guard.
void main() {
  testWidgets('map home shell matches the golden', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/map_home_shell.png'),
    );
  });
}
