import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';

/// The green "Friends" chip under the search bar, with a live-count badge.
///
/// The chip opens the friends screen (`/friends`); the badge zooms the map to
/// frame everyone who is sharing right now (`map.fitFriends`) — the same command
/// agents use.
class FriendsChip extends ConsumerWidget {
  const FriendsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int liveCount = ref.watch(friendLocationsProvider).length;
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PlaySpace.md),
      child: Row(
        children: <Widget>[
          PlayChip(
            label: 'Friends',
            icon: PlayIcons.friends,
            onTap: () => context.push('/friends'),
          ),
          if (liveCount > 0) ...<Widget>[
            const SizedBox(width: PlaySpace.sm),
            _LiveCountBadge(
              count: liveCount,
              onTap: () => unawaited(
                ref
                    .read(commandRegistryProvider)
                    .dispatch('map.fitFriends', const <String, Object?>{})
                    .catchError((Object error) {
                      if (context.mounted) {
                        showPlayToast(
                          context,
                          'No friend is sharing right now',
                        );
                      }
                      return null;
                    }),
              ),
            ),
          ],
          if (!signedIn) ...<Widget>[
            const Spacer(),
            PlayButton(
              label: 'Sign in',
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: () => context.push('/profile'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "N friends live" pill; tapping frames every live friend on the map.
class _LiveCountBadge extends StatelessWidget {
  const _LiveCountBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      tone: PlayTone.soft,
      radius: PlayRadii.pill,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.symmetric(
        horizontal: PlaySpace.sm,
        vertical: PlaySpace.xs,
      ),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF1B9C6B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: PlaySpace.xs),
          Text(
            count == 1 ? '1 friend live' : '$count friends live',
            style: PlayType.caption.copyWith(
              color: colors.onPrimarySoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
