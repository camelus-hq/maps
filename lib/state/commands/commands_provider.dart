import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'command_registry.dart';
import 'commands.dart';

/// The app's command registry.
final Provider<CommandRegistry> commandRegistryProvider =
    Provider<CommandRegistry>((Ref ref) => CommandRegistry(buildCommands(ref)));
