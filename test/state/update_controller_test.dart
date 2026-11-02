import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_app_installer.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_release_source.dart';
import 'package:openmaps/data/fakes/fake_settings_repository.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/update.dart';

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

  ProviderContainer build({
    AppRelease? release,
    AppException? releaseFailure,
    AppVersion version = installed,
    FakeAppInstaller? installer,
    FakeSettingsRepository? settings,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(version: version),
        ),
        releaseSourceProvider.overrideWithValue(
          FakeReleaseSource(release: release, failure: releaseFailure),
        ),
        appInstallerProvider.overrideWithValue(installer ?? FakeAppInstaller()),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? FakeSettingsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'check surfaces an available release and the installed version',
    () async {
      final ProviderContainer container = build(release: newer);

      await container.read(updateControllerProvider.notifier).check();

      final UpdateState state = container.read(updateControllerProvider);
      expect(state.status, UpdateStatus.available);
      expect(state.updateAvailable, isTrue);
      expect(state.shouldPrompt, isTrue);
      expect(state.installed, installed);
      expect(state.release?.versionName, '1.4.0');
    },
  );

  test('check is up to date when the installed version is not older', () async {
    final ProviderContainer container = build(
      release: newer,
      version: const AppVersion(versionCode: 2002, versionName: '1.4.0'),
    );

    await container.read(updateControllerProvider.notifier).check();

    final UpdateState state = container.read(updateControllerProvider);
    expect(state.status, UpdateStatus.upToDate);
    expect(state.shouldPrompt, isFalse);
  });

  test('a manifest failure becomes an error state', () async {
    final ProviderContainer container = build(
      releaseFailure: const OfflineException('You are offline'),
    );

    await container.read(updateControllerProvider.notifier).check();

    final UpdateState state = container.read(updateControllerProvider);
    expect(state.status, UpdateStatus.error);
    expect(state.error, 'You are offline');
  });

  test('declining persists the version code and hides the prompt', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository();
    final ProviderContainer container = build(
      release: newer,
      settings: settings,
    );
    await container.read(updateControllerProvider.notifier).check();

    await container.read(updateControllerProvider.notifier).dismissPrompt();

    expect(container.read(updateControllerProvider).shouldPrompt, isFalse);
    expect(await settings.skippedUpdateVersionCode(), 2002);

    // A later check for the same release keeps it dismissed.
    await container.read(updateControllerProvider.notifier).check();
    expect(container.read(updateControllerProvider).shouldPrompt, isFalse);
    // But it is still offered (the settings screen uses this).
    expect(container.read(updateControllerProvider).updateAvailable, isTrue);
  });

  test('a declined release still prompts when a newer one appears', () async {
    final FakeSettingsRepository settings = FakeSettingsRepository();
    final ProviderContainer container = build(
      release: newer,
      settings: settings,
    );
    await container.read(updateControllerProvider.notifier).check();
    await container.read(updateControllerProvider.notifier).dismissPrompt();

    // Publish a newer release.
    (container.read(releaseSourceProvider) as FakeReleaseSource).release =
        AppRelease(versionCode: 2003, versionName: '1.5.0', apkUrl: _apkUrl);
    await container.read(updateControllerProvider.notifier).check();

    expect(container.read(updateControllerProvider).shouldPrompt, isTrue);
  });

  test('install runs the installer and reports progress', () async {
    final FakeAppInstaller installer = FakeAppInstaller();
    final ProviderContainer container = build(
      release: newer,
      installer: installer,
    );
    await container.read(updateControllerProvider.notifier).check();

    await container.read(updateControllerProvider.notifier).install();

    expect(installer.installs, <AppRelease>[newer]);
    final UpdateState state = container.read(updateControllerProvider);
    expect(state.installing, isFalse);
    expect(state.error, isNull);
  });

  test('a failed install surfaces the error', () async {
    final FakeAppInstaller installer = FakeAppInstaller(
      failure: const UnsupportedException('No installer here'),
    );
    final ProviderContainer container = build(
      release: newer,
      installer: installer,
    );
    await container.read(updateControllerProvider.notifier).check();

    await container.read(updateControllerProvider.notifier).install();

    final UpdateState state = container.read(updateControllerProvider);
    expect(state.installing, isFalse);
    expect(state.error, 'No installer here');
  });
}
