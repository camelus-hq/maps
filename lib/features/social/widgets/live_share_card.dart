import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/live_share.dart';
import '../../../state/social.dart';
import '../screens/share_live_location_sheet.dart';

/// The live-location status card above the bottom navigation.
///
/// Off: a short explainer with a "Share live" action (the reference app's row).
/// On: who can see you, until when, and a "Stop" action. The countdown refreshes
/// on every published update (the share publishes at least every 30 s), so it
/// needs no timer of its own.
class LiveShareCard extends ConsumerWidget {
  const LiveShareCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final LiveShareState share = ref.watch(liveShareProvider);
    final bool active = share.isActive;
    final DateTime? expiresAt = share.expiresAt;
    final String? error = share.error;

    final String subtitle;
    if (active && expiresAt != null) {
      final int count = share.recipientCount;
      final String friends = count == 1 ? '1 friend' : '$count friends';
      final Duration left = share.remainingAt(DateTime.now()) ?? Duration.zero;
      subtitle =
          'Visible to $friends until ${formatClockTime(expiresAt)} '
          '(${formatDuration(left)} left)';
    } else {
      subtitle = 'Choose who sees it and for how long.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                active ? Icons.near_me : Icons.shield_outlined,
                color: active
                    ? const Color(0xFF1B9C6B)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      active
                          ? 'Sharing your live location'
                          : 'Your live location is off',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (error != null)
                      Text(
                        error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (share.isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (active)
                TextButton(
                  onPressed: () =>
                      unawaited(ref.read(liveShareProvider.notifier).stop()),
                  child: const Text('Stop'),
                )
              else
                FilledButton(
                  onPressed: () =>
                      unawaited(showShareLiveLocationSheet(context)),
                  child: const Text('Share live'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
