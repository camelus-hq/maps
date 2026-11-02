import 'dart:convert';

import 'control_client.dart';
import 'screenshot_source.dart';

typedef JsonMap = Map<String, Object?>;

/// An MCP tool: a name, a JSON schema and a handler returning MCP content.
class Tool {
  const Tool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.run,
  });

  final String name;
  final String description;
  final JsonMap inputSchema;
  final Future<JsonMap> Function(JsonMap arguments) run;
}

const JsonMap _emptySchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{},
  'additionalProperties': false,
};

JsonMap _text(Object? value) => <String, Object?>{
  'content': <JsonMap>[
    <String, Object?>{
      'type': 'text',
      'text': value is String ? value : jsonEncode(value),
    },
  ],
  'isError': false,
};

JsonMap _error(String message) => <String, Object?>{
  'content': <JsonMap>[
    <String, Object?>{'type': 'text', 'text': message},
  ],
  'isError': true,
};

/// The OpenMaps MCP tool set. Same surface in every mode; the backend is the
/// [ControlClient] (bridge to a running app, or a fake in tests).
List<Tool> buildTools({
  required ControlClient control,
  required ScreenshotSource screenshot,
}) {
  return <Tool>[
    Tool(
      name: 'openmaps_list_commands',
      description:
          'List every command the app exposes (id + description) from the live '
          'command registry.',
      inputSchema: _emptySchema,
      run: (JsonMap arguments) async =>
          _text(await control.call('session.list')),
    ),
    Tool(
      name: 'openmaps_execute',
      description:
          'Dispatch any app command by id — the same path a tap takes. '
          'Examples: search.query {text}, place.select {id}, route.plan {id}, '
          'nav.start {live}, ui.tap {x,y}, ui.swipe {fromX,fromY,toX,toY}.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'method': <String, Object?>{'type': 'string'},
          'params': <String, Object?>{'type': 'object'},
        },
        'required': <String>['method'],
        'additionalProperties': false,
      },
      run: (JsonMap arguments) async {
        final Object? method = arguments['method'];
        if (method is! String || method.trim().isEmpty) {
          return _error('"method" is required');
        }
        final Object? rawParams = arguments['params'];
        final JsonMap params = rawParams is Map<String, Object?>
            ? rawParams
            : const <String, Object?>{};
        try {
          return _text(await control.call(method.trim(), params));
        } on ControlException catch (error) {
          return _error('${error.code}: ${error.message}');
        }
      },
    ),
    Tool(
      name: 'openmaps_state',
      description:
          'A snapshot of app state (ready, build mode, camera, style, traffic, '
          'config flags).',
      inputSchema: _emptySchema,
      run: (JsonMap arguments) async => _text(await control.call('app.state')),
    ),
    Tool(
      name: 'openmaps_screenshot',
      description:
          'Capture a PNG of the running app. Returns an image (adb screencap, '
          'which includes the Mapbox platform view); falls back to the in-app '
          'ui.screenshot, which returns the file path.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'path': <String, Object?>{
            'type': 'string',
            'description': 'Optional app-side path for the fallback capture.',
          },
        },
        'additionalProperties': false,
      },
      run: (JsonMap arguments) async {
        final List<int>? bytes = await screenshot.capture();
        if (bytes != null && bytes.isNotEmpty) {
          return <String, Object?>{
            'content': <JsonMap>[
              <String, Object?>{
                'type': 'image',
                'data': base64Encode(bytes),
                'mimeType': 'image/png',
              },
            ],
            'isError': false,
          };
        }
        final Object? path = arguments['path'];
        final Object? result = await control.call(
          'ui.screenshot',
          path is String && path.isNotEmpty
              ? <String, Object?>{'path': path}
              : const <String, Object?>{},
        );
        return _text(result);
      },
    ),
  ];
}
