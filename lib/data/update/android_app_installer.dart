import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/ports/app_installer.dart';

/// [AppInstaller] that downloads the release APK to the app's private cache,
/// verifies its SHA-256 when the manifest carries one, and hands it to the
/// Android package installer through a small platform channel
/// (`openmaps/installer` → `MainActivity.installApk`).
///
/// On a platform/build where the channel is absent the call fails with
/// [UnsupportedException], so the UI can offer the download link instead.
/// Every failure is a typed [AppException]; a corrupt or oversized download is
/// discarded and never installed.
class AndroidAppInstaller implements AppInstaller {
  AndroidAppInstaller({
    required this.client,
    this.channel = const MethodChannel('openmaps/installer'),
    Future<Directory> Function()? directory,
    this.connectTimeout = const Duration(seconds: 30),
    this.streamTimeout = const Duration(seconds: 60),
    this.maxBytes = 400 * 1024 * 1024,
  }) : _directory = directory ?? getTemporaryDirectory;

  final http.Client client;

  /// The platform channel the Android side answers on.
  final MethodChannel channel;

  /// Resolves the app's cache directory (injectable so the download path can be
  /// unit-tested without the platform channel).
  final Future<Directory> Function() _directory;

  /// How long to wait for the download to start.
  final Duration connectTimeout;

  /// The longest allowed gap between two chunks of the download.
  final Duration streamTimeout;

  /// A hard cap on the download size (an APK is tens of MB; 400 MB is a guard
  /// against a hostile or runaway endpoint).
  final int maxBytes;

  @override
  Future<void> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final File file = await _download(release, onProgress);
    try {
      await channel.invokeMethod<void>('installApk', <String, Object?>{
        'path': file.path,
      });
    } on MissingPluginException catch (error) {
      throw UnsupportedException(
        'Updating inside the app is not available on this build — use the '
        'download link instead.',
        cause: error,
      );
    } on PlatformException catch (error) {
      throw UnknownException(
        error.message ?? 'The installer could not be opened',
        cause: error,
      );
    }
  }

  Future<File> _download(
    AppRelease release,
    void Function(double progress)? onProgress,
  ) async {
    final Directory cache = await _directory();
    final Directory updates = Directory('${cache.path}/updates');
    if (!updates.existsSync()) {
      await updates.create(recursive: true);
    }
    // Drop any previous download so the cache cannot grow without bound.
    await for (final FileSystemEntity entity in updates.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {
          // Best effort; a locked file is harmless.
        }
      }
    }

    final File file = File(
      '${updates.path}/openmaps-${release.versionCode}.apk',
    );
    final IOSink sink = file.openWrite();
    final _DigestSink digestSink = _DigestSink();
    final ByteConversionSink hasher = sha256.startChunkedConversion(digestSink);

    http.StreamedResponse response;
    try {
      final http.Request request = http.Request('GET', release.apkUrl)
        ..headers['User-Agent'] = 'OpenMaps/0.1 (Flutter; self-update)';
      response = await client.send(request).timeout(connectTimeout);
    } on TimeoutException catch (error) {
      await sink.close();
      await _delete(file);
      throw RequestTimeoutException(
        'The update download timed out',
        cause: error,
      );
    } on http.ClientException catch (error) {
      await sink.close();
      await _delete(file);
      throw OfflineException('Could not download the update', cause: error);
    } catch (error) {
      await sink.close();
      await _delete(file);
      throw NetworkException('Could not download the update', cause: error);
    }

    if (response.statusCode != 200) {
      await sink.close();
      await _delete(file);
      throw NetworkException(
        'Could not download the update (HTTP ${response.statusCode})',
      );
    }
    final int? total = response.contentLength;
    if (total != null && total > maxBytes) {
      await sink.close();
      await _delete(file);
      throw const ValidationException('The update is too large to install');
    }

    int received = 0;
    bool failed = false;
    try {
      await for (final List<int> chunk in response.stream.timeout(
        streamTimeout,
      )) {
        received += chunk.length;
        if (received > maxBytes) {
          throw const ValidationException('The update is too large to install');
        }
        sink.add(chunk);
        hasher.add(chunk);
        if (onProgress != null) {
          onProgress(total == null || total <= 0 ? 0 : received / total);
        }
      }
    } on TimeoutException catch (error) {
      failed = true;
      throw RequestTimeoutException(
        'The update download stalled',
        cause: error,
      );
    } on http.ClientException catch (error) {
      failed = true;
      throw OfflineException('Could not download the update', cause: error);
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      hasher.close();
      await sink.close();
      if (failed) {
        await _delete(file);
      }
    }

    final String? expected = release.sha256;
    if (expected != null) {
      final String actual = digestSink.value?.toString() ?? '';
      if (actual != expected) {
        await _delete(file);
        throw const ValidationException(
          'The downloaded update failed its checksum — it was discarded',
        );
      }
    }
    return file;
  }

  Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort.
    }
  }
}

/// Collects the single [Digest] a `startChunkedConversion` sink produces.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
