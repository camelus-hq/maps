import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/control/control_server.dart';
import 'package:openmaps/state/commands/commands_provider.dart';

void main() {
  late ProviderContainer container;
  late ControlServer server;
  late Socket socket;

  setUp(() async {
    container = ProviderContainer();
    server = ControlServer(
      registry: container.read(commandRegistryProvider),
      port: 0,
    );
    await server.start();
    final int port =
        server.boundPort ?? (throw StateError('server did not bind'));
    socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  });

  tearDown(() async {
    socket.destroy();
    await server.stop();
    container.dispose();
  });

  Future<Map<String, Object?>> roundTrip(Object? request) async {
    socket.writeln(jsonEncode(request));
    final String line = await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    return jsonDecode(line) as Map<String, Object?>;
  }

  test('round-trips a command over JSON lines', () async {
    final Map<String, Object?> response = await roundTrip(<String, Object?>{
      'id': 1,
      'method': 'app.ready',
    });
    expect(response['id'], 1);
    expect(response['result'], isTrue);
  });

  test('unknown method yields an error object, not a crash', () async {
    final Map<String, Object?> response = await roundTrip(<String, Object?>{
      'id': 2,
      'method': 'does.not.exist',
    });
    final Map<String, Object?> error =
        response['error'] as Map<String, Object?>;
    expect(error['code'], 'unknown_command');
  });

  test('a command with hostile params yields a structured error', () async {
    final Map<String, Object?> response = await roundTrip(<String, Object?>{
      'id': 3,
      'method': 'ui.tap',
      'params': <String, Object?>{'x': 'nope', 'y': null},
    });
    final Map<String, Object?> error =
        response['error'] as Map<String, Object?>;
    expect(error['code'], 'bad_params');
  });

  test('malformed JSON yields a bad_request error', () async {
    socket.writeln('this is not json');
    final String line = await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final Map<String, Object?> response =
        jsonDecode(line) as Map<String, Object?>;
    final Map<String, Object?> error =
        response['error'] as Map<String, Object?>;
    expect(error['code'], 'bad_request');
  });
}
