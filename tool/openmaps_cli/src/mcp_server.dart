import 'dart:convert';

import 'control_client.dart';
import 'screenshot_source.dart';
import 'tools.dart';

/// A structured MCP error returned as a JSON-RPC `error` object.
class McpError implements Exception {
  McpError(this.code, this.message);

  final int code;
  final String message;
}

/// A minimal Model Context Protocol server over JSON-RPC 2.0.
///
/// [handleLine] takes one inbound message and returns the response line (or
/// `null` for notifications). Transport (stdio, HTTP, …) lives in the caller,
/// which keeps this unit-testable without a process or a socket.
class McpServer {
  McpServer({required this.control, ScreenshotSource? screenshot})
    : _tools = buildTools(
        control: control,
        screenshot: screenshot ?? const NoScreenshotSource(),
      );

  final ControlClient control;
  final List<Tool> _tools;

  static const String protocolVersion = '2024-11-05';
  static const String serverName = 'openmaps-cli';
  static const String serverVersion = '0.1.0';

  /// Handles a single JSON-RPC message.
  Future<String?> handleLine(String line) async {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return _errorResponse(null, -32700, 'Parse error');
    }
    if (decoded is! Map<String, Object?>) {
      return _errorResponse(null, -32600, 'Request must be a JSON object');
    }

    final Object? id = decoded['id'];
    final bool isNotification = !decoded.containsKey('id');
    final Object? method = decoded['method'];
    if (method is! String || method.isEmpty) {
      return isNotification
          ? null
          : _errorResponse(id, -32600, 'Missing "method"');
    }

    final Object? rawParams = decoded['params'];
    final Map<String, Object?> params = rawParams is Map<String, Object?>
        ? rawParams
        : const <String, Object?>{};

    try {
      final Object? result = await _dispatch(method, params);
      return isNotification
          ? null
          : jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': id,
              'result': result,
            });
    } on McpError catch (error) {
      return isNotification
          ? null
          : _errorResponse(id, error.code, error.message);
    } catch (error) {
      return isNotification ? null : _errorResponse(id, -32603, '$error');
    }
  }

  String _errorResponse(Object? id, int code, String message) =>
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, Object?>{'code': code, 'message': message},
      });

  Future<Object?> _dispatch(String method, Map<String, Object?> params) async {
    switch (method) {
      case 'initialize':
        return <String, Object?>{
          'protocolVersion': protocolVersion,
          'capabilities': <String, Object?>{
            'tools': <String, Object?>{'listChanged': false},
          },
          'serverInfo': <String, Object?>{
            'name': serverName,
            'version': serverVersion,
          },
        };
      case 'notifications/initialized':
        return null;
      case 'ping':
        return <String, Object?>{};
      case 'tools/list':
        return <String, Object?>{
          'tools': <Map<String, Object?>>[
            for (final Tool tool in _tools)
              <String, Object?>{
                'name': tool.name,
                'description': tool.description,
                'inputSchema': tool.inputSchema,
              },
          ],
        };
      case 'tools/call':
        final Object? name = params['name'];
        final Tool? tool = _find(name);
        if (tool == null) {
          throw McpError(-32602, 'Unknown tool: $name');
        }
        final Object? rawArgs = params['arguments'];
        final Map<String, Object?> args = rawArgs is Map<String, Object?>
            ? rawArgs
            : const <String, Object?>{};
        return tool.run(args);
      default:
        throw McpError(-32601, 'Method not found: $method');
    }
  }

  Tool? _find(Object? name) {
    for (final Tool tool in _tools) {
      if (tool.name == name) {
        return tool;
      }
    }
    return null;
  }
}
