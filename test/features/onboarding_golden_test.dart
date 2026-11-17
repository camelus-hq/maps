import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_settings_repository.dart';
import 'package:openmaps/state/ports.dart';

/// Goldens for the two first-run onboarding steps (terms, then location), so a
/// layout regression on the very first screen is caught.
void main() {
  Future<void> pumpFirstRun(WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await repository.setOnboardingSeen(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('terms step matches the golden', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFirstRun(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_terms.png'),
    );
  });

  testWidgets('location step matches the golden', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFirstRun(tester);
    await tester.tap(find.text('Accept & continue'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_location.png'),
    );
  });
}
