import 'dart:convert';
import 'dart:io';

import '../src/control_client.dart';
import '../src/mcp_server.dart';
import '../src/screenshot_source.dart';

/// `openmaps_cli mcp [--connect host:port] [--serial <adb-serial>] [--headless]`
///
/// A stdio MCP server exposing `openmaps_list_commands`, `openmaps_execute`,
/// `openmaps_state` and `openmaps_screenshot` (AGENTS.md §Driving the app).
///
/// Bridge mode (`--connect`) drives a running debug/profile build through the
/// JSON-lines control channel — reach it with `adb forward tcp:7981 tcp:7981`
/// after launching with `--control 7981`. Headless mode is intentionally not
/// implemented yet: the command registry lives in the Riverpod/Flutter state
/// layer, so running it without an engine needs a design decision (see
/// `docs/mcp.md`).
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first != 'mcp') {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  final _Options options = _parse(args.skip(1).toList());

  if (options.headless) {
    stderr.writeln(
      'headless mode is not implemented yet: the command registry lives in the '
      'Riverpod/Flutter state layer and needs a Flutter engine. Use '
      '`--connect host:port` against a running app instead (see docs/mcp.md).',
    );
    exitCode = 2;
    return;
  }

  final String? connect = options.connect;
  if (connect == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  final Uri? endpoint = Uri.tryParse('tcp://$connect');
  final int? port = endpoint?.hasPort ?? false ? endpoint!.port : null;
  final String host = endpoint?.host ?? '';
  if (port == null || host.isEmpty) {
    stderr.writeln('invalid --connect "$connect" (expected host:port)');
    exitCode = 64;
    return;
  }

  final ControlClient control = BridgeControlClient(host, port);
  final McpServer server = McpServer(
    control: control,
    screenshot: AdbScreenshotSource(serial: options.serial),
  );

  final Stream<String> input = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final String line in input) {
    final String? response = await server.handleLine(line);
    if (response != null) {
      stdout.writeln(response);
    }
  }
  await control.close();
}

const String _usage =
    'usage: openmaps_cli mcp [--connect host:port] [--serial <adb-serial>] '
    '[--headless]';

class _Options {
  String? connect;
  String? serial;
  bool headless = false;
}

_Options _parse(List<String> args) {
  final _Options options = _Options();
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (arg.startsWith('--connect=')) {
      options.connect = arg.substring('--connect='.length);
    } else if (arg == '--connect' && i + 1 < args.length) {
      options.connect = args[++i];
    } else if (arg.startsWith('--serial=')) {
      options.serial = arg.substring('--serial='.length);
    } else if (arg == '--serial' && i + 1 < args.length) {
      options.serial = args[++i];
    } else if (arg == '--headless') {
      options.headless = true;
    }
  }
  return options;
}
