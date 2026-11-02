import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/ports/release_source.dart';

/// [ReleaseSource] backed by an HTTP(S) JSON manifest.
///
/// The manifest is external, hostile input: the body is parsed leniently, every
/// field is bounded, and anything missing or malformed yields `null` (no usable
/// release) or a typed [AppException] — never a crash. Shape:
///
/// ```json
/// {
///   "versionCode": 2001,
///   "versionName": "1.4.0",
///   "apkUrl": "https://example.com/app/app-arm64-v8a-release.apk",
///   "sha256": "9f2b…",
///   "mandatory": false,
///   "releaseNotes": "Bug fixes and performance improvements"
/// }
/// ```
class HttpReleaseSource implements ReleaseSource {
  HttpReleaseSource({
    required this.client,
    required this.manifestUrl,
    this.timeout = const Duration(seconds: 10),
    this.userAgent = defaultUserAgent,
    this.maxBodyBytes = 256 * 1024,
  });

  static const String defaultUserAgent = 'OpenMaps/0.1 (Flutter; self-update)';

  /// The manifest URL (from `--dart-define=UPDATE_MANIFEST_URL=…`).
  final String manifestUrl;

  final http.Client client;

  final Duration timeout;

  final String userAgent;

  /// A sane upper bound on the manifest body; anything larger is refused.
  final int maxBodyBytes;

  @override
  Future<AppRelease?> fetchLatest() async {
    final Uri? uri = Uri.tryParse(manifestUrl.trim());
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw const ValidationException('The update URL is not an http(s) URL');
    }
    if (uri.host.isEmpty) {
      throw const ValidationException('The update URL has no host');
    }

    final http.Response response;
    try {
      response = await client
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'User-Agent': userAgent,
            },
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw RequestTimeoutException(
        'Checking for an update took too long',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw OfflineException('Could not check for an update', cause: error);
    } catch (error) {
      throw NetworkException('Could not check for an update', cause: error);
    }

    if (response.statusCode == 404 || response.statusCode == 410) {
      // The manifest is simply not published (yet) — "no updates", not an
      // error. This also keeps the placeholder default (example.com) quiet.
      return null;
    }
    if (response.statusCode != 200) {
      throw NetworkException(
        'Could not check for an update (HTTP ${response.statusCode})',
      );
    }
    if (response.bodyBytes.length > maxBodyBytes) {
      throw const ValidationException('The update manifest is too large');
    }
    return parseRelease(response.body);
  }

  /// Parses a manifest body into an [AppRelease], or `null` when it does not
  /// describe a usable release. Exposed for tests; the body is untrusted.
  static AppRelease? parseRelease(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw ValidationException(
        'The update manifest is not valid JSON',
        cause: error,
      );
    }
    if (decoded is! Map) {
      throw const ValidationException('The update manifest is malformed');
    }

    final int? versionCode = _positiveInt(decoded['versionCode']);
    final String? versionName = _string(decoded['versionName'], 40);
    final String? apkUrlRaw = _string(decoded['apkUrl'], 2048);
    if (versionCode == null || versionName == null || apkUrlRaw == null) {
      // Missing a required field: not a usable release (never a crash).
      return null;
    }

    final Uri? apkUrl = Uri.tryParse(apkUrlRaw);
    if (apkUrl == null ||
        !(apkUrl.scheme == 'https' || apkUrl.scheme == 'http') ||
        apkUrl.host.isEmpty) {
      return null;
    }

    return AppRelease(
      versionCode: versionCode,
      versionName: versionName,
      apkUrl: apkUrl,
      sha256: _sha256(decoded['sha256']),
      mandatory: decoded['mandatory'] == true,
      // Release notes can be a long, bulleted changelog (see the fastlane
      // lane), so the cap is generous — the prompt scrolls them.
      releaseNotes: _string(decoded['releaseNotes'], 8000) ?? '',
    );
  }

  /// A 64-char lower-case hex string, or `null` for anything else.
  static String? _sha256(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String value = raw.trim().toLowerCase();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(value) ? value : null;
  }

  static int? _positiveInt(Object? raw) {
    final int? value = switch (raw) {
      final int v => v,
      final double v => v.isFinite ? v.toInt() : null,
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (value == null || value <= 0 || value > 2100000000) {
      return null;
    }
    return value;
  }

  static String? _string(Object? raw, int maxLength) {
    if (raw is! String) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }
}
