/// A parameterised command invocation (from the control channel, the UI, or a
/// test).
class CommandRequest {
  const CommandRequest({required this.id, required this.params});

  final String id;
  final Map<String, Object?> params;
}

/// Handler for a [Command]; returns a JSON-serialisable result.
typedef CommandHandler = Future<Object?> Function(CommandRequest request);

/// A single drivable action. Every user-visible action must be reachable by
/// dispatching its command id through the same path the UI uses.
class Command {
  const Command({
    required this.id,
    required this.description,
    required this.handler,
  });

  final String id;
  final String description;
  final CommandHandler handler;
}

/// A failure the control channel reports as a structured `error` object
/// instead of crashing the connection.
class CommandException implements Exception {
  const CommandException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CommandException($code: $message)';
}
