import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/push_notifications.dart';

/// Keeps the push registration + foreground-notification bridge alive for as
/// long as the map home is mounted (the app's persistent screen), and mounts
/// nowhere visible. Mirrors `NavigationNotificationLayer`.
///
/// It also watches the app lifecycle: while the app is in the foreground the
/// server is told to pause forwarding (`setForeground(true)`) because the app is
/// receiving gift wraps on its own relay subscription; going to the background
/// resumes server pushes.
class PushNotificationLayer extends ConsumerStatefulWidget {
  const PushNotificationLayer({super.key});

  @override
  ConsumerState<PushNotificationLayer> createState() =>
      _PushNotificationLayerState();
}

class _PushNotificationLayerState extends ConsumerState<PushNotificationLayer> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => _setForeground(true),
      onPause: () => _setForeground(false),
      onHide: () => _setForeground(false),
      onDetach: () => _setForeground(false),
    );
    // The layer mounts on the already-visible map home, so start foreground;
    // a later background/resume transition corrects it.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _setForeground(true);
      }
    });
  }

  void _setForeground(bool foreground) {
    ref.read(pushStatusProvider.notifier).setForeground(foreground);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushStatusProvider);
    return const SizedBox.shrink();
  }
}
