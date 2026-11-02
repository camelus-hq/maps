import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/core/errors/result.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_release_source.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/domain/usecases/check_for_update.dart';

void main() {
  const AppVersion installed = AppVersion(
    versionCode: 2001,
    versionName: '1.3.0',
  );
  final AppRelease newer = AppRelease(
    versionCode: 2002,
    versionName: '1.4.0',
    apkUrl: Uri.parse('https://example.com/app/app.apk'),
    releaseNotes: 'Bug fixes',
  );

  test('reports the installed version and a newer release', () async {
    final CheckForUpdate check = CheckForUpdate(
      FakeAppVersionSource(version: installed),
      FakeReleaseSource(release: newer),
    );

    final Result<UpdateCheck> result = await check();

    final UpdateCheck value = (result as Ok<UpdateCheck>).value;
    expect(value.installed, installed);
    expect(value.latest, newer);
    expect(value.updateAvailable, isTrue);
  });

  test('is up to date when the manifest has no release', () async {
    final CheckForUpdate check = CheckForUpdate(
      FakeAppVersionSource(version: installed),
      FakeReleaseSource(),
    );

    final UpdateCheck value = ((await check()) as Ok<UpdateCheck>).value;

    expect(value.latest, isNull);
    expect(value.updateAvailable, isFalse);
  });

  test('surfaces a manifest failure as a Result error', () async {
    final CheckForUpdate check = CheckForUpdate(
      FakeAppVersionSource(version: installed),
      FakeReleaseSource(failure: const OfflineException('offline')),
    );

    final Result<UpdateCheck> result = await check();

    expect(result, isA<Err<UpdateCheck>>());
    expect((result as Err<UpdateCheck>).error, isA<OfflineException>());
  });
}
