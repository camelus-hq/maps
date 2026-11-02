import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          ActionChip(
            avatar: Icon(
              Icons.people_alt_outlined,
              size: 18,
              color: scheme.primary,
            ),
            label: const Text('Friends'),
            onPressed: () => context.push('/friends'),
          ),
          if (liveCount > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            _LiveCountBadge(
              count: liveCount,
              onTap: () => unawaited(
                ref
                    .read(commandRegistryProvider)
                    .dispatch('map.fitFriends', const <String, Object?>{})
                    .catchError((Object error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No friend is sharing right now'),
                          ),
                        );
                      }
                      return null;
                    }),
              ),
            ),
          ],
          if (!signedIn) ...<Widget>[
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/profile'),
              child: const Text('Sign in'),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
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
              const SizedBox(width: AppSpacing.xs),
              Text(
                count == 1 ? '1 friend live' : '$count friends live',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
