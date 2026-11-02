import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_app_installer.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_release_source.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/ports.dart';

final Uri _apkUrl = Uri.parse('https://example.com/app/app.apk');

/// The self-update flow must be drivable by command id (AGENTS.md
/// §Driving the app), not only through the UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppRelease newer = AppRelease(
    versionCode: 2002,
    versionName: '1.4.0',
    apkUrl: _apkUrl,
    mandatory: true,
    releaseNotes: 'Bug fixes',
  );

  late FakeAppInstaller installer;
  late ProviderContainer container;

  setUp(() {
    installer = FakeAppInstaller();
    container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 2001, versionName: '1.3.0'),
          ),
        ),
        releaseSourceProvider.overrideWithValue(
          FakeReleaseSource(release: newer),
        ),
        appInstallerProvider.overrideWithValue(installer),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<Map<String, Object?>> dispatch(String id) async =>
      await container
              .read(commandRegistryProvider)
              .dispatch(id, const <String, Object?>{})
          as Map<String, Object?>;

  test('app.update.check reports the available release', () async {
    final Map<String, Object?> state = await dispatch('app.update.check');

    expect(state['status'], 'available');
    expect(state['skipped'], isFalse);
    final Map<Object?, Object?> available =
        state['available']! as Map<Object?, Object?>;
    expect(available['versionName'], '1.4.0');
    expect(available['versionCode'], 2002);
    expect(available['mandatory'], isTrue);
    expect(available['releaseNotes'], 'Bug fixes');
  });

  test(
    'app.update.dismiss records the decline and app.update.install runs',
    () async {
      await dispatch('app.update.check');

      final Map<String, Object?> dismissed = await dispatch(
        'app.update.dismiss',
      );
      expect(dismissed['skipped'], isTrue);

      final Map<String, Object?> installed = await dispatch(
        'app.update.install',
      );
      expect(installed['installing'], isFalse);
      expect(installer.installs, <AppRelease>[newer]);
    },
  );

  test('app.update.state is honest before any check', () async {
    final Map<String, Object?> state = await dispatch('app.update.state');

    expect(state['status'], 'idle');
    expect(state['available'], isNull);
  });
}
