/// Parsed command-line arguments for the control channel.
class ControlArgs {
  const ControlArgs({this.port});

  /// TCP port for the JSON-lines control channel, or `null` when disabled.
  final int? port;

  static const String _flag = '--control';

  /// Reads `--control <port>` or `--control=<port>`; ignores anything invalid so
  /// a bad flag never prevents the app from starting.
  static ControlArgs parse(List<String> args) {
    for (int i = 0; i < args.length; i++) {
      final String arg = args[i];
      final String? rawPort;
      if (arg == _flag) {
        rawPort = i + 1 < args.length ? args[i + 1] : null;
      } else if (arg.startsWith('$_flag=')) {
        rawPort = arg.substring(_flag.length + 1);
      } else {
        continue;
      }
      final int? port = int.tryParse(rawPort ?? '');
      if (port != null && port > 0 && port <= 65535) {
        return ControlArgs(port: port);
      }
    }
    return const ControlArgs();
  }
}
