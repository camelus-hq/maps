import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/app_update.dart';

void main() {
  group('compareVersionNames', () {
    test('orders dotted versions numerically, not lexically', () {
      expect(compareVersionNames('1.4.0', '1.10.0'), lessThan(0));
      expect(compareVersionNames('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersionNames('1.4.0', '1.4.0'), 0);
    });

    test('treats a missing segment as zero', () {
      expect(compareVersionNames('1.4', '1.4.0'), 0);
      expect(compareVersionNames('1.4', '1.4.1'), lessThan(0));
    });

    test('ignores a build suffix and compares the release part', () {
      expect(compareVersionNames('1.4.0+91', '1.4.0'), 0);
    });
  });

  group('AppRelease.isNewerThan', () {
    const AppVersion installed = AppVersion(
      versionCode: 2001,
      versionName: '0.1.0',
    );

    test('uses the versionCode when both sides have one', () {
      final AppRelease newer = _release(
        versionCode: 2002,
        versionName: '0.0.1',
      );
      final AppRelease same = _release(versionCode: 2001, versionName: '9.9.9');
      final AppRelease older = _release(
        versionCode: 2000,
        versionName: '9.9.9',
      );
      expect(newer.isNewerThan(installed), isTrue);
      expect(same.isNewerThan(installed), isFalse);
      expect(older.isNewerThan(installed), isFalse);
    });

    test('falls back to the versionName when a code is missing', () {
      final AppRelease release = _release(versionCode: 0, versionName: '1.4.0');
      expect(release.isNewerThan(installed), isTrue);
      final AppRelease same = _release(versionCode: 0, versionName: '0.1.0');
      expect(same.isNewerThan(installed), isFalse);
    });
  });

  group('UpdateCheck', () {
    test('reports an update when the release is newer', () {
      final UpdateCheck check = UpdateCheck(
        installed: AppVersion(versionCode: 1, versionName: '1.0.0'),
        latest: AppRelease(versionCode: 2, versionName: '1.1.0', apkUrl: _url),
      );
      expect(check.updateAvailable, isTrue);
    });

    test('is up to date with no release or an older one', () {
      const UpdateCheck none = UpdateCheck(
        installed: AppVersion(versionCode: 1, versionName: '1.0.0'),
      );
      expect(none.updateAvailable, isFalse);
      final UpdateCheck outdated = UpdateCheck(
        installed: AppVersion(versionCode: 2, versionName: '1.1.0'),
        latest: AppRelease(versionCode: 1, versionName: '1.0.0', apkUrl: _url),
      );
      expect(outdated.updateAvailable, isFalse);
    });
  });

  group('AppRelease.changes', () {
    test('splits notes into change lines and strips bullet markers', () {
      final AppRelease release = AppRelease(
        versionCode: 2,
        versionName: '1.1.0',
        apkUrl: _url,
        releaseNotes: '- feat: one\n\n* fix: two\nplain three\n• four\n',
      );
      expect(release.changes, <String>[
        'feat: one',
        'fix: two',
        'plain three',
        'four',
      ]);
    });

    test('is empty for empty notes', () {
      final AppRelease release = AppRelease(
        versionCode: 2,
        versionName: '1.1.0',
        apkUrl: _url,
      );
      expect(release.changes, isEmpty);
    });
  });
}

final Uri _url = Uri.parse('https://example.com/app/app.apk');

AppRelease _release({required int versionCode, required String versionName}) =>
    AppRelease(
      versionCode: versionCode,
      versionName: versionName,
      apkUrl: _url,
    );
