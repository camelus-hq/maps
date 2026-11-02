import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/openmaps_cli/src/control_client.dart';
import '../../tool/openmaps_cli/src/mcp_server.dart';
import '../../tool/openmaps_cli/src/screenshot_source.dart';

class FakeControlClient implements ControlClient {
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Future<Object?> call(
    String method, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) async {
    calls.add(<String, Object?>{'method': method, 'params': params});
    return switch (method) {
      'session.list' => <Object?>[
        <String, Object?>{'id': 'app.ready', 'description': 'ready'},
      ],
      'app.state' => <String, Object?>{'ready': true, 'buildMode': 'debug'},
      'search.query' => <Object?>[
        <String, Object?>{
          'id': 'poi.1',
          'name': 'Coffee',
          'lat': 52.5,
          'lon': 13.4,
        },
      ],
      'ui.screenshot' => <String, Object?>{
        'path': '/tmp/shot.png',
        'bytes': 12,
      },
      _ => throw ControlException('unknown_command', method),
    };
  }

  @override
  Future<void> close() async => closed = true;
}

class FakeScreenshot implements ScreenshotSource {
  FakeScreenshot(this.bytes);

  final List<int>? bytes;

  @override
  Future<List<int>?> capture() async => bytes;
}

Future<Map<String, Object?>> _send(
  McpServer server, {
  Object? id,
  required String method,
  Map<String, Object?>? params,
}) async {
  final String? response = await server.handleLine(
    jsonEncode(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    }),
  );
  return jsonDecode(response!) as Map<String, Object?>;
}

void main() {
  late FakeControlClient control;
  late McpServer server;

  setUp(() {
    control = FakeControlClient();
    server = McpServer(control: control, screenshot: FakeScreenshot(null));
  });

  test('initialize reports protocol version and server info', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 1,
      method: 'initialize',
    );
    final Map<String, Object?> result =
        response['result'] as Map<String, Object?>;
    expect(result['protocolVersion'], McpServer.protocolVersion);
    expect(
      (result['serverInfo'] as Map<String, Object?>)['name'],
      'openmaps-cli',
    );
  });

  test('tools/list exposes the four tools', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 2,
      method: 'tools/list',
    );
    final List<Object?> tools =
        (response['result'] as Map<String, Object?>)['tools'] as List<Object?>;
    final Set<Object?> names = tools
        .map((Object? tool) => (tool as Map<String, Object?>)['name'])
        .toSet();
    expect(
      names,
      containsAll(<String>[
        'openmaps_list_commands',
        'openmaps_execute',
        'openmaps_state',
        'openmaps_screenshot',
      ]),
    );
  });

  test('openmaps_list_commands returns the registry as a text block', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 3,
      method: 'tools/call',
      params: <String, Object?>{'name': 'openmaps_list_commands'},
    );
    final Map<String, Object?> result =
        response['result'] as Map<String, Object?>;
    expect(result['isError'], isFalse);
    final List<Object?> content = result['content'] as List<Object?>;
    final String text =
        (content.first as Map<String, Object?>)['text']! as String;
    expect(text, contains('app.ready'));
    expect(control.calls.single['method'], 'session.list');
  });

  test('openmaps_execute forwards method and params', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 4,
      method: 'tools/call',
      params: <String, Object?>{
        'name': 'openmaps_execute',
        'arguments': <String, Object?>{
          'method': 'search.query',
          'params': <String, Object?>{'text': 'coffee'},
        },
      },
    );
    expect((response['result'] as Map<String, Object?>)['isError'], isFalse);
    expect(control.calls.single['method'], 'search.query');
    expect(
      (control.calls.single['params']! as Map<String, Object?>)['text'],
      'coffee',
    );
  });

  test('openmaps_execute surfaces a control error as isError', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 5,
      method: 'tools/call',
      params: <String, Object?>{
        'name': 'openmaps_execute',
        'arguments': <String, Object?>{'method': 'nope'},
      },
    );
    final Map<String, Object?> result =
        response['result'] as Map<String, Object?>;
    expect(result['isError'], isTrue);
  });

  test('an unknown tool is a JSON-RPC error', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 6,
      method: 'tools/call',
      params: <String, Object?>{'name': 'does.not.exist'},
    );
    final Map<String, Object?> error =
        response['error'] as Map<String, Object?>;
    expect(error['code'], -32602);
  });

  test('an unknown method is a JSON-RPC error', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 7,
      method: 'does.not.exist',
    );
    expect((response['error'] as Map<String, Object?>)['code'], -32601);
  });

  test('a notification gets no response', () async {
    final String? response = await server.handleLine(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }),
    );
    expect(response, isNull);
  });

  test('malformed JSON is a parse error', () async {
    final String? response = await server.handleLine('not json');
    final Map<String, Object?> decoded =
        jsonDecode(response!) as Map<String, Object?>;
    expect((decoded['error'] as Map<String, Object?>)['code'], -32700);
  });

  test(
    'openmaps_screenshot returns an image block when adb captures',
    () async {
      final McpServer imageServer = McpServer(
        control: control,
        screenshot: FakeScreenshot(<int>[137, 80, 78, 71]),
      );
      final Map<String, Object?> response = await _send(
        imageServer,
        id: 8,
        method: 'tools/call',
        params: <String, Object?>{'name': 'openmaps_screenshot'},
      );
      final List<Object?> content =
          (response['result'] as Map<String, Object?>)['content']
              as List<Object?>;
      final Map<String, Object?> block = content.first as Map<String, Object?>;
      expect(block['type'], 'image');
      expect(block['mimeType'], 'image/png');
      expect(base64Decode(block['data']! as String), <int>[137, 80, 78, 71]);
    },
  );

  test('openmaps_screenshot falls back to ui.screenshot', () async {
    final Map<String, Object?> response = await _send(
      server,
      id: 9,
      method: 'tools/call',
      params: <String, Object?>{'name': 'openmaps_screenshot'},
    );
    final List<Object?> content =
        (response['result'] as Map<String, Object?>)['content']
            as List<Object?>;
    expect(
      ((content.first as Map<String, Object?>)['text']! as String),
      contains('shot.png'),
    );
    expect(control.calls.single['method'], 'ui.screenshot');
  });
}
