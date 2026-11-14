import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_app_installer.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_release_source.dart';
import 'package:openmaps/data/fakes/fake_settings_repository.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/features/update/widgets/update_prompt.dart';
import 'package:openmaps/state/ports.dart';

final Uri _apkUrl = Uri.parse('https://example.com/app/app.apk');

void main() {
  const AppVersion installed = AppVersion(
    versionCode: 2001,
    versionName: '1.3.0',
  );
  final AppRelease newer = AppRelease(
    versionCode: 2002,
    versionName: '1.4.0',
    apkUrl: _apkUrl,
    releaseNotes: 'Bug fixes and performance improvements',
  );
  final AppRelease mandatory = AppRelease(
    versionCode: 2002,
    versionName: '1.4.0',
    apkUrl: _apkUrl,
    mandatory: true,
  );

  Future<FakeSettingsRepository> pumpHost(
    WidgetTester tester, {
    AppRelease? release,
    FakeAppInstaller? installer,
    AppVersion version = installed,
  }) async {
    final FakeSettingsRepository settings = FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appVersionSourceProvider.overrideWithValue(
            FakeAppVersionSource(version: version),
          ),
          releaseSourceProvider.overrideWithValue(
            FakeReleaseSource(release: release ?? newer),
          ),
          appInstallerProvider.overrideWithValue(
            installer ?? FakeAppInstaller(),
          ),
          settingsRepositoryProvider.overrideWithValue(settings),
        ],
        child: const MaterialApp(
          home: UpdatePromptHost(child: Scaffold(body: Text('map'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('prompts when a newer release is advertised', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('1.4.0'), findsOneWidget);
    expect(find.text('Bug fixes and performance improvements'), findsOneWidget);
  });

  testWidgets('stays silent when the app is up to date', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      version: const AppVersion(versionCode: 2002, versionName: '1.4.0'),
    );

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('Later hides the prompt and records the declined version', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository settings = await pumpHost(tester);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
    expect(await settings.skippedUpdateVersionCode(), 2002);
  });

  testWidgets('Update runs the installer', (WidgetTester tester) async {
    final FakeAppInstaller installer = FakeAppInstaller();
    await pumpHost(tester, installer: installer);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(installer.installs, <AppRelease>[newer]);
  });

  testWidgets('a mandatory update offers no Later', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester, release: mandatory);

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('lists a long changelog in a scrollable area', (
    WidgetTester tester,
  ) async {
    final String notes = List<String>.generate(
      40,
      (int i) => '- change $i',
    ).join('\n');

    await pumpHost(
      tester,
      release: AppRelease(
        versionCode: 2002,
        versionName: '1.4.0',
        apkUrl: _apkUrl,
        releaseNotes: notes,
      ),
    );

    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('change 0'), findsOneWidget);
    expect(find.text('change 39'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    // The action stays reachable without scrolling through the list.
    expect(find.text('Update'), findsOneWidget);
  });
}
