import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A failure reported by the OpenMaps control channel.
class ControlException implements Exception {
  ControlException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ControlException($code): $message';
}

/// A client for the app's JSON-lines control channel (`lib/control/`).
abstract interface class ControlClient {
  /// Dispatch a command and return its serialisable result.
  Future<Object?> call(String method, [Map<String, Object?> params]);

  Future<void> close();
}

/// Talks to a running debug/profile app over TCP (`--connect host:port`,
/// reached on the host via `adb forward tcp:7981 tcp:7981`).
///
/// Requests are serialised so responses can be matched to their ids without a
/// background reader; the connection is opened lazily and reused.
class BridgeControlClient implements ControlClient {
  BridgeControlClient(this.host, this.port);

  final String host;
  final int port;

  Socket? _socket;
  StreamIterator<String>? _lines;
  int _nextId = 0;
  Future<void> _lock = Future<void>.value();

  Future<void> _connect() async {
    if (_socket != null) {
      return;
    }
    final Socket socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    _socket = socket;
    _lines = StreamIterator<String>(
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
  }

  @override
  Future<Object?> call(
    String method, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    final Completer<Object?> completer = Completer<Object?>();
    _lock = _lock.then((_) async {
      try {
        await _connect();
        final int id = ++_nextId;
        final Map<String, Object?> request = <String, Object?>{
          'id': id,
          'method': method,
          if (params.isNotEmpty) 'params': params,
        };
        _socket!.writeln(jsonEncode(request));

        final StreamIterator<String> lines = _lines!;
        while (await lines.moveNext()) {
          final String line = lines.current.trim();
          if (line.isEmpty) {
            continue;
          }
          final Object? decoded = jsonDecode(line);
          if (decoded is! Map<String, Object?> || decoded['id'] != id) {
            continue;
          }
          final Object? error = decoded['error'];
          if (error is Map<String, Object?>) {
            throw ControlException(
              (error['code'] ?? 'error').toString(),
              (error['message'] ?? 'command failed').toString(),
            );
          }
          completer.complete(decoded['result']);
          return;
        }
        throw ControlException('disconnected', 'control channel closed');
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      }
    });
    return completer.future;
  }

  @override
  Future<void> close() async {
    await _lines?.cancel();
    _lines = null;
    _socket?.destroy();
    _socket = null;
  }
}
