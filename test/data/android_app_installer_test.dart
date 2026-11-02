import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/update/android_app_installer.dart';
import 'package:openmaps/domain/entities/app_update.dart';

/// A client that streams [bytes] back as a 200 response, so the installer's
/// download + checksum path can be exercised without a network.
class _StreamClient extends http.BaseClient {
  _StreamClient(this.bytes, {this.statusCode = 200});

  final List<int> bytes;
  final int statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final Stream<List<int>> stream = Stream<List<int>>.fromIterable(<List<int>>[
      bytes.sublist(0, bytes.length ~/ 2),
      bytes.sublist(bytes.length ~/ 2),
    ]);
    return http.StreamedResponse(
      stream,
      statusCode,
      contentLength: bytes.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('openmaps/installer');

  late Directory temp;
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    temp = Directory.systemTemp.createTempSync('openmaps-update-test');
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  void answerInstalls() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
  }

  AppRelease releaseWith({String? sha256}) => AppRelease(
    versionCode: 10,
    versionName: '1.4.0',
    apkUrl: Uri.parse('https://example.com/app/app.apk'),
    sha256: sha256,
  );

  test('downloads, verifies and asks the platform to install', () async {
    answerInstalls();
    final List<int> bytes = List<int>.generate(2048, (int i) => i % 251);
    final AndroidAppInstaller installer = AndroidAppInstaller(
      client: _StreamClient(bytes),
      directory: () async => temp,
    );
    final List<double> progress = <double>[];

    await installer.install(
      releaseWith(sha256: sha256.convert(bytes).toString()),
      onProgress: progress.add,
    );

    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'installApk');
    final Map<Object?, Object?> args =
        calls.single.arguments as Map<Object?, Object?>;
    final Object? path = args['path'];
    expect(path, isA<String>());
    expect(File(path! as String).existsSync(), isTrue);
  });

  test('discards a download whose checksum does not match', () async {
    answerInstalls();
    final List<int> bytes = List<int>.filled(1024, 7);
    final AndroidAppInstaller installer = AndroidAppInstaller(
      client: _StreamClient(bytes),
      directory: () async => temp,
    );

    await expectLater(
      installer.install(releaseWith(sha256: 'b' * 64)),
      throwsA(isA<ValidationException>()),
    );

    expect(calls, isEmpty);
    final Directory updates = Directory('${temp.path}/updates');
    final Iterable<File> files = updates.existsSync()
        ? updates.listSync().whereType<File>()
        : const <File>[];
    expect(files, isEmpty, reason: 'the bad download must be discarded');
  });

  test('skips verification when the manifest carries no checksum', () async {
    answerInstalls();
    final AndroidAppInstaller installer = AndroidAppInstaller(
      client: _StreamClient(<int>[1, 2, 3, 4]),
      directory: () async => temp,
    );

    await installer.install(releaseWith());

    expect(calls, hasLength(1));
  });

  test('reports unsupported when the platform channel is absent', () async {
    // No mock handler is registered for the channel.
    final AndroidAppInstaller installer = AndroidAppInstaller(
      client: _StreamClient(<int>[1, 2, 3, 4]),
      directory: () async => temp,
    );

    await expectLater(
      installer.install(releaseWith()),
      throwsA(isA<UnsupportedException>()),
    );
  });

  test('maps a non-200 download to a network error', () async {
    answerInstalls();
    final AndroidAppInstaller installer = AndroidAppInstaller(
      client: _StreamClient(<int>[1, 2, 3], statusCode: 500),
      directory: () async => temp,
    );

    await expectLater(
      installer.install(releaseWith()),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, isEmpty);
  });
}
