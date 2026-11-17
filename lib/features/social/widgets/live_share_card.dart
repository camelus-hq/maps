import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/utils/format.dart';
import '../../../domain/entities/live_share.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
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
    final PlayColors colors = PlayColors.of(context);
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
        PlaySpace.md,
        PlaySpace.sm,
        PlaySpace.md,
        PlaySpace.sm,
      ),
      child: PlaySurface(
        radius: PlayRadii.lg,
        borderWidth: 1,
        padding: const EdgeInsets.symmetric(
          horizontal: PlaySpace.md,
          vertical: PlaySpace.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              active ? PlayIcons.nearby : PhosphorIconsRegular.shield,
              color: active ? const Color(0xFF1B9C6B) : colors.primary,
            ),
            const SizedBox(width: PlaySpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    active
                        ? 'Sharing your live location'
                        : 'Your live location is off',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.bodyStrong.copyWith(color: colors.ink),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                  if (error != null)
                    Text(
                      error,
                      style: PlayType.caption.copyWith(color: colors.coral),
                    ),
                ],
              ),
            ),
            const SizedBox(width: PlaySpace.sm),
            if (share.isBusy)
              const PlaySpinner(size: 20, strokeWidth: 2)
            else if (active)
              PlayButton(
                label: 'Stop',
                variant: PlayButtonVariant.ghost,
                size: PlayButtonSize.sm,
                onPressed: () =>
                    unawaited(ref.read(liveShareProvider.notifier).stop()),
              )
            else
              PlayButton(
                label: 'Share live',
                size: PlayButtonSize.sm,
                onPressed: () => unawaited(showShareLiveLocationSheet(context)),
              ),
          ],
        ),
      ),
    );
  }
}
