import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_settings_repository.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  testWidgets('first run shows onboarding, then the map', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await repository.setOnboardingSeen(false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OpenMaps'), findsOneWidget);
    expect(find.text('Search here'), findsNothing);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OpenMaps'), findsNothing);
    expect(find.text('Search here'), findsOneWidget);
  });
}
