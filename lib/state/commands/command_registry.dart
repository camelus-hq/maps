import 'command.dart';

/// The single source of truth for drivable actions.
///
/// `session.list`/`session.help` are built in so every registry answers for
/// itself; feature commands are supplied by the composition root.
class CommandRegistry {
  CommandRegistry(List<Command> commands) {
    _commands = <String, Command>{
      for (final Command command in commands) command.id: command,
      'session.list': Command(
        id: 'session.list',
        description: 'List every command id and its description.',
        handler: (CommandRequest request) async => _describeAll(),
      ),
      'session.help': Command(
        id: 'session.help',
        description: 'Describe one command (params: {id}) or all of them.',
        handler: (CommandRequest request) async {
          final Object? wanted = request.params['id'];
          if (wanted is String && wanted.isNotEmpty) {
            final Command? command = _commands[wanted];
            if (command == null) {
              throw CommandException(
                'unknown_command',
                'Unknown command: $wanted',
              );
            }
            return _describe(command);
          }
          return _describeAll();
        },
      ),
    };
  }

  late final Map<String, Command> _commands;

  List<Command> get commands {
    final List<Command> sorted = _commands.values.toList()
      ..sort((Command a, Command b) => a.id.compareTo(b.id));
    return List<Command>.unmodifiable(sorted);
  }

  Command? lookup(String id) => _commands[id];

  Future<Object?> dispatch(String id, Map<String, Object?> params) {
    final Command? command = _commands[id];
    if (command == null) {
      throw CommandException('unknown_command', 'Unknown command: $id');
    }
    return command.handler(CommandRequest(id: id, params: params));
  }

  List<Map<String, Object?>> _describeAll() =>
      commands.map(_describe).toList(growable: false);

  Map<String, Object?> _describe(Command command) => <String, Object?>{
    'id': command.id,
    'description': command.description,
  };
}
