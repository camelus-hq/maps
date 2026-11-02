import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../state/commands/command.dart';
import '../state/commands/command_registry.dart';

/// JSON-lines control channel: one JSON object per line,
/// `{"id":1,"method":"…","params":{…}}` → `{"id":1,"result":…}` or
/// `{"id":1,"error":{…}}`.
///
/// Debug/profile only, bound to localhost (never release). Errors never crash
/// the connection: hostile input yields an `error` object.
class ControlServer {
  ControlServer({required this.registry, required this.port});

  final CommandRegistry registry;
  final int port;

  ServerSocket? _server;
  final List<Socket> _clients = <Socket>[];

  /// The port actually bound (useful when [port] is 0 for tests).
  int? get boundPort => _server?.port;

  Future<void> start() async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    _server = server;
    server.listen(_handleClient);
  }

  Future<void> stop() async {
    for (final Socket client in List<Socket>.of(_clients)) {
      client.destroy();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
  }

  void _handleClient(Socket socket) {
    _clients.add(socket);
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (String line) => unawaited(_handleLine(socket, line)),
          onError: (Object _) => socket.destroy(),
          onDone: () => _clients.remove(socket),
          cancelOnError: true,
        );
  }

  Future<void> _handleLine(Socket socket, String line) async {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Object? id;
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, Object?>) {
        throw const CommandException(
          'bad_request',
          'Request must be a JSON object',
        );
      }
      id = decoded['id'];
      final Object? method = decoded['method'];
      if (method is! String || method.isEmpty) {
        throw const CommandException('bad_request', 'Missing "method"');
      }
      final Object? rawParams = decoded['params'];
      final Map<String, Object?> params = rawParams is Map<String, Object?>
          ? rawParams
          : const <String, Object?>{};
      final Object? result = await registry.dispatch(method, params);
      _write(socket, <String, Object?>{'id': id, 'result': result});
    } on CommandException catch (error) {
      _write(socket, <String, Object?>{
        'id': id,
        'error': <String, Object?>{
          'code': error.code,
          'message': error.message,
        },
      });
    } on FormatException catch (_) {
      _write(socket, <String, Object?>{
        'id': id,
        'error': <String, Object?>{
          'code': 'bad_request',
          'message': 'Request is not valid JSON',
        },
      });
    } catch (_) {
      _write(socket, <String, Object?>{
        'id': id,
        'error': <String, Object?>{
          'code': 'internal',
          'message': 'Command failed',
        },
      });
    }
  }

  void _write(Socket socket, Map<String, Object?> payload) {
    try {
      socket.writeln(jsonEncode(payload));
    } catch (_) {
      socket.destroy();
    }
  }
}
