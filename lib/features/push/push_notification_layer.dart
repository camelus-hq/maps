import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/push_notifications.dart';

/// Keeps the push registration + foreground-notification bridge alive for as
/// long as the map home is mounted (the app's persistent screen), and mounts
/// nowhere visible. Mirrors `NavigationNotificationLayer`.
class PushNotificationLayer extends ConsumerWidget {
  const PushNotificationLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushStatusProvider);
    return const SizedBox.shrink();
  }
}
