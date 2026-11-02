import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/friend.dart';
import '../../../domain/entities/friend_location.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../../state/social.dart';
import '../../common/navigation.dart';
import '../widgets/friend_avatar.dart';
import 'share_live_location_sheet.dart';

/// The friends screen (`/friends`): who is sharing with you, and the entry
/// point to start sharing your own live location.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);
    final List<FriendLocation> live = ref.watch(friendLocationsProvider);
    final Map<String, FriendLocation> liveByPubkey = <String, FriendLocation>{
      for (final FriendLocation location in live) location.pubkey: location,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Manage friends',
            onPressed: () => context.push('/friends/manage'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'You',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: !signedIn
            ? _signedOut(context, theme)
            : Column(
                children: <Widget>[
                  Expanded(
                    child: friends.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (Object error, StackTrace stack) => _error(
                        context,
                        theme,
                        onRetry: () => unawaited(
                          ref.read(friendsProvider.notifier).refresh(),
                        ),
                      ),
                      data: (List<Friend> list) =>
                          _list(context, ref, list, liveByPubkey),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            unawaited(showShareLiveLocationSheet(context)),
                        icon: const Icon(Icons.share_location_outlined),
                        label: const Text('Share live location'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _signedOut(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.people_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'See where your friends are',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sign in with Nostr to follow your friends and share your live '
              'location with them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.push('/profile'),
              child: const Text('Sign in with Nostr'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(
    BuildContext context,
    ThemeData theme, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline),
            const SizedBox(height: AppSpacing.sm),
            const Text('Could not load your friends'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<Friend> friends,
    Map<String, FriendLocation> liveByPubkey,
  ) {
    final LatLon? me = ref.watch(userLocationProvider).value;
    final bool imperial = ref.watch(imperialUnitsProvider);
    final List<Friend> live = <Friend>[];
    final List<Friend> offline = <Friend>[];
    for (final Friend friend in friends) {
      if (liveByPubkey.containsKey(friend.pubkey)) {
        live.add(friend);
      } else {
        offline.add(friend);
      }
    }
    if (friends.isEmpty) {
      return _empty(context, ref);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: <Widget>[
        if (live.isNotEmpty) ...<Widget>[
          _sectionLabel(context, 'LIVE NOW'),
          for (final Friend friend in live)
            _row(
              context,
              ref,
              friend,
              liveByPubkey[friend.pubkey],
              me,
              imperial,
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        _sectionLabel(context, 'ALL FRIENDS'),
        for (final Friend friend in offline)
          _row(context, ref, friend, null, me, imperial),
      ],
    );
  }

  /// The empty state: friends come from the NIP-51 "friends" set, which the
  /// user fills deliberately (from the people they follow, or by scanning an
  /// npub) — nothing is copied in automatically.
  Widget _empty(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.people_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No friends yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add people to your "friends" list to share your live location '
              'with them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/friends/manage'),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Add friends'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600),
    ),
  );

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
    FriendLocation? location,
    LatLon? me,
    bool imperial,
  ) {
    final ThemeData theme = Theme.of(context);
    final LatLon? position = location?.position;
    String subtitle = 'Friend';
    if (position != null) {
      final String where = me == null
          ? 'Live'
          : 'Live · ${formatDistance(me.distanceTo(position), imperial: imperial)} away';
      subtitle = where;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: FriendAvatar(
        label: friend.label,
        pictureUrl: friend.pictureUrl,
        borderColor: location == null ? null : const Color(0xFF1B9C6B),
      ),
      title: Text(friend.label),
      subtitle: Text(subtitle),
      trailing: location == null
          ? null
          : Icon(Icons.near_me, size: 18, color: theme.colorScheme.primary),
      onTap: () {
        if (location == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${friend.label} is not sharing right now')),
          );
          return;
        }
        // Opens their card *and* moves the camera to where they are, then hands
        // the user back to the map (`social.friend.select {focus: true}`).
        unawaited(
          ref.read(commandRegistryProvider).dispatch(
            'social.friend.select',
            <String, Object?>{'pubkey': friend.pubkey},
          ),
        );
        popOrHome(context);
      },
    );
  }
}
