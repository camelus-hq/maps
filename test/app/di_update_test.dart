import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/di.dart';
import 'package:openmaps/core/config/app_config.dart';
import 'package:openmaps/data/fakes/fake_release_source.dart';
import 'package:openmaps/data/update/http_release_source.dart';
import 'package:openmaps/domain/ports/release_source.dart';
import 'package:openmaps/state/ports.dart';

/// The self-updater is wired only for the `direct` Android flavor: the `play`
/// flavor updates through Google Play, and a build with no flavor (or a
/// non-Android platform) keeps the keyless default that advertises no release,
/// so no update prompt can ever offer a direct APK.
void main() {
  // `flutter test` reports Android, so `_supportsSelfUpdate` is true here and
  // the flavour is the only variable under test.
  ProviderContainer container(AppConfig config) =>
      ProviderContainer(overrides: buildAppOverrides(config));

  test('the direct flavor wires the HTTP self-updater', () {
    final ProviderContainer c = container(
      const AppConfig(
        appFlavor: AppConfig.directFlavor,
        updateManifestUrl: 'https://updates.test/version.json',
      ),
    );
    addTearDown(c.dispose);

    final ReleaseSource source = c.read(releaseSourceProvider);
    expect(source, isA<HttpReleaseSource>());
    expect(
      (source as HttpReleaseSource).manifestUrl,
      'https://updates.test/version.json',
    );
  });

  test('the play flavor keeps the keyless (no-release) default', () {
    final ProviderContainer c = container(
      const AppConfig(appFlavor: AppConfig.playFlavor),
    );
    addTearDown(c.dispose);

    expect(c.read(releaseSourceProvider), isA<FakeReleaseSource>());
  });

  test('an absent flavor keeps the keyless default', () {
    final ProviderContainer c = container(AppConfig.empty);
    addTearDown(c.dispose);

    expect(c.read(releaseSourceProvider), isA<FakeReleaseSource>());
  });
}
