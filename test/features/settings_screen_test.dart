import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_app_installer.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_release_source.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/app_settings.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/features/settings/screens/settings_screen.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/settings.dart';
import 'package:openmaps/state/update.dart';

final Uri _apkUrl = Uri.parse('https://example.com/app/app.apk');

void main() {
  testWidgets('settings screen changes units and theme', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).unit, DistanceUnit.imperial);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).theme, AppThemeMode.dark);
  });

  testWidgets('shows the signed-in account and signs out', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = FakeSocialService();
    addTearDown(social.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The signed-in identity is shown with a way out.
    expect(find.text('Friend 1111'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(social.isLoggedIn, isFalse);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('the developer option toggles listing every OSM tag', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).showOsmTags, isFalse);

    final Finder toggle = find.text('Show all OpenStreetMap tags');
    await tester.scrollUntilVisible(toggle, 200);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).showOsmTags, isTrue);
  });

  testWidgets('the search provider setting switches to OpenStreetMap', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).searchBackend,
      SearchBackend.mapbox,
    );

    final Finder choice = find.text('OpenStreetMap');
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).searchBackend,
      SearchBackend.openstreetmap,
    );
  });

  testWidgets('the Camelus option is offered and selects the service set', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choice = find.text('Camelus');
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).searchBackend,
      SearchBackend.camelus,
    );
  });

  testWidgets('shows the installed version from the platform metadata', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 1234, versionName: '2.3.4'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder row = find.text('Installed version');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    expect(find.text('2.3.4 (1234)'), findsOneWidget);
  });

  testWidgets('offers an available update and installs it', (
    WidgetTester tester,
  ) async {
    final AppRelease release = AppRelease(
      versionCode: 2002,
      versionName: '1.4.0',
      apkUrl: _apkUrl,
    );
    final FakeAppInstaller installer = FakeAppInstaller();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 2001, versionName: '1.3.0'),
          ),
        ),
        releaseSourceProvider.overrideWithValue(
          FakeReleaseSource(release: release),
        ),
        appInstallerProvider.overrideWithValue(installer),
      ],
    );
    addTearDown(container.dispose);
    await container.read(updateControllerProvider.notifier).check();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder row = find.text('Update available — 1.4.0');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(installer.installs, <AppRelease>[release]);
  });

  testWidgets('still offers the update after the prompt was declined', (
    WidgetTester tester,
  ) async {
    final AppRelease release = AppRelease(
      versionCode: 2002,
      versionName: '1.4.0',
      apkUrl: _apkUrl,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 2001, versionName: '1.3.0'),
          ),
        ),
        releaseSourceProvider.overrideWithValue(
          FakeReleaseSource(release: release),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(updateControllerProvider.notifier).check();
    await container.read(updateControllerProvider.notifier).dismissPrompt();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder row = find.text('Update available — 1.4.0');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
  });

  testWidgets('surfaces an install failure on the update row', (
    WidgetTester tester,
  ) async {
    final AppRelease release = AppRelease(
      versionCode: 2002,
      versionName: '1.4.0',
      apkUrl: _apkUrl,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 2001, versionName: '1.3.0'),
          ),
        ),
        releaseSourceProvider.overrideWithValue(
          FakeReleaseSource(release: release),
        ),
        appInstallerProvider.overrideWithValue(
          FakeAppInstaller(failure: const UnsupportedException('No installer')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(updateControllerProvider.notifier).check();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder row = find.text('Update available — 1.4.0');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('No installer'), findsOneWidget);
  });

  testWidgets('summarises the changelog on the update row', (
    WidgetTester tester,
  ) async {
    final AppRelease release = AppRelease(
      versionCode: 2002,
      versionName: '1.4.0',
      apkUrl: _apkUrl,
      releaseNotes: '- first change\n- second change\n- third change',
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 2001, versionName: '1.3.0'),
          ),
        ),
        releaseSourceProvider.overrideWithValue(
          FakeReleaseSource(release: release),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(updateControllerProvider.notifier).check();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder row = find.text('Update available — 1.4.0');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    expect(find.textContaining('first change'), findsOneWidget);
    expect(find.textContaining('+2 more'), findsOneWidget);
  });
}
