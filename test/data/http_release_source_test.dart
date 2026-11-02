import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/update/http_release_source.dart';
import 'package:openmaps/domain/entities/app_update.dart';

import 'offline_client.dart';

/// The update manifest is external, hostile input: a bad field must drop or
/// default, and a bad body must be a typed error — never a crash.
void main() {
  HttpReleaseSource source(
    Future<http.Response> Function(http.Request request) handler, {
    String url = 'https://example.com/app/version.json',
  }) {
    return HttpReleaseSource(client: MockClient(handler), manifestUrl: url);
  }

  group('fetchLatest', () {
    test('parses a well-formed manifest', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response(
          '{"versionCode":2001,"versionName":"1.4.0",'
          '"apkUrl":"https://example.com/app/app-arm64-v8a-release.apk",'
          '"sha256":"9f2b","mandatory":true,"releaseNotes":"Fixes"}',
          200,
        ),
      );

      final AppRelease? release = await service.fetchLatest();

      expect(release, isNotNull);
      expect(release!.versionCode, 2001);
      expect(release.versionName, '1.4.0');
      expect(
        release.apkUrl.toString(),
        'https://example.com/app/app-arm64-v8a-release.apk',
      );
      // "9f2b" is not a 64-char hex digest, so it is dropped (no checksum).
      expect(release.sha256, isNull);
      expect(release.mandatory, isTrue);
      expect(release.releaseNotes, 'Fixes');
    });

    test('keeps a valid sha256 and defaults mandatory to false', () async {
      final String digest = 'a' * 64;
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response(
          '{"versionCode":2,"versionName":"1.0.0","apkUrl":"https://e.com/a.apk",'
          '"sha256":"$digest"}',
          200,
        ),
      );

      final AppRelease release = (await service.fetchLatest())!;

      expect(release.sha256, digest);
      expect(release.mandatory, isFalse);
      expect(release.releaseNotes, '');
    });

    test('returns null when a required field is missing', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async =>
            http.Response('{"versionName":"1.4.0"}', 200),
      );
      expect(await service.fetchLatest(), isNull);
    });

    test('returns null for a non-http apkUrl', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response(
          '{"versionCode":2,"versionName":"1.0.0","apkUrl":"ftp://e.com/a.apk"}',
          200,
        ),
      );
      expect(await service.fetchLatest(), isNull);
    });

    test('rejects invalid JSON with a typed error', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response('<html>nope</html>', 200),
      );
      await expectLater(
        service.fetchLatest(),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects a non-object body with a typed error', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response('[1,2,3]', 200),
      );
      await expectLater(
        service.fetchLatest(),
        throwsA(isA<ValidationException>()),
      );
    });

    test('treats an unpublished manifest as "no release"', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response('Not Found', 404),
      );
      expect(await service.fetchLatest(), isNull);
    });

    test('maps a server error to a network error', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response('boom', 500),
      );
      await expectLater(
        service.fetchLatest(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps a connection failure to offline', () async {
      final HttpReleaseSource service = HttpReleaseSource(
        client: OfflineHttpClient(),
        manifestUrl: 'https://example.com/app/version.json',
      );
      await expectLater(
        service.fetchLatest(),
        throwsA(isA<OfflineException>()),
      );
    });

    test('rejects a non-http manifest URL', () async {
      final HttpReleaseSource service = source(
        (http.Request request) async => http.Response('{}', 200),
        url: 'not a url',
      );
      await expectLater(
        service.fetchLatest(),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('parseRelease (hostile input)', () {
    test('never throws an unexpected error on hostile field shapes', () {
      const List<String> payloads = <String>[
        '{}',
        '{"versionCode":"x","versionName":5,"apkUrl":false}',
        '{"versionCode":-1,"versionName":"","apkUrl":"https://e.com/a.apk"}',
        '{"versionCode":99999999999,"versionName":"1","apkUrl":"https://e.com/a"}',
        '{"versionCode":1,"versionName":"1","apkUrl":"javascript:alert(1)"}',
        '{"versionCode":1,"versionName":"1","apkUrl":"https://","sha256":"zz"}',
        'null',
        '"a string"',
        '42',
      ];
      for (final String payload in payloads) {
        AppRelease? release;
        try {
          release = HttpReleaseSource.parseRelease(payload);
        } on ValidationException {
          // A malformed body is a *typed* failure, which the use case catches —
          // never a crash.
          continue;
        }
        // Otherwise it parsed: every field must be sane.
        if (release != null) {
          expect(release.versionCode, greaterThan(0));
          expect(release.versionName, isNotEmpty);
          expect(release.apkUrl.host, isNotEmpty);
        }
      }
    });

    test('caps oversized text fields', () {
      final String hugeName = 'x' * 5000;
      final AppRelease? release = HttpReleaseSource.parseRelease(
        '{"versionCode":1,"versionName":"$hugeName",'
        '"apkUrl":"https://e.com/a.apk","releaseNotes":"$hugeName"}',
      );
      expect(release, isNotNull);
      expect(release!.versionName.length, lessThanOrEqualTo(40));
      expect(release.releaseNotes.length, lessThanOrEqualTo(8000));
    });
  });
}
