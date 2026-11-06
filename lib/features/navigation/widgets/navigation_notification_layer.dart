import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/navigation_notifications.dart';

/// Keeps the navigation-notification bridge alive for as long as the map home
/// is mounted (the app's persistent screen), so the ongoing trip notice appears
/// and is dismissed with guidance. Invisible — it only reads the provider.
class NavigationNotificationLayer extends ConsumerWidget {
  const NavigationNotificationLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(navigationNoticeProvider);
    return const SizedBox.shrink();
  }
}
