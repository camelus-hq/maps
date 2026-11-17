import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

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
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';
import 'share_live_location_sheet.dart';

/// The friends screen (`/friends`): who is sharing with you, and the entry
/// point to start sharing your own live location.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);
    final List<FriendLocation> live = ref.watch(friendLocationsProvider);
    final Map<String, FriendLocation> liveByPubkey = <String, FriendLocation>{
      for (final FriendLocation location in live) location.pubkey: location,
    };

    return PlayScaffold(
      appBar: PlayAppBar(
        title: 'Friends',
        actions: <Widget>[
          PlayIconButton(
            icon: PhosphorIconsRegular.userGear,
            variant: PlayIconButtonVariant.plain,
            size: 44,
            semanticLabel: 'Manage friends',
            onPressed: () => context.push('/friends/manage'),
          ),
          PlayIconButton(
            icon: PlayIcons.person,
            variant: PlayIconButtonVariant.plain,
            size: 44,
            semanticLabel: 'You',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      child: !signedIn
          ? _signedOut(context)
          : Column(
              children: <Widget>[
                Expanded(
                  child: friends.when(
                    loading: () => const Center(child: PlaySpinner()),
                    error: (Object error, StackTrace stack) => _error(
                      context,
                      onRetry: () => unawaited(
                        ref.read(friendsProvider.notifier).refresh(),
                      ),
                    ),
                    data: (List<Friend> list) =>
                        _list(context, ref, list, liveByPubkey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(PlaySpace.lg),
                  child: PlayButton(
                    label: 'Share live location',
                    icon: PhosphorIconsRegular.broadcast,
                    expand: true,
                    onPressed: () =>
                        unawaited(showShareLiveLocationSheet(context)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _signedOut(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.friends, size: 56, color: colors.primary),
            const SizedBox(height: PlaySpace.md),
            Text(
              'See where your friends are',
              style: PlayType.title.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.sm),
            Text(
              'Sign in with Nostr to follow your friends and share your live '
              'location with them.',
              textAlign: TextAlign.center,
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.lg),
            PlayButton(
              label: 'Sign in with Nostr',
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(BuildContext context, {required VoidCallback onRetry}) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.error, color: colors.ink),
            const SizedBox(height: PlaySpace.sm),
            Text(
              'Could not load your friends',
              style: PlayType.body.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.md),
            PlayButton(
              label: 'Retry',
              variant: PlayButtonVariant.ghost,
              onPressed: onRetry,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
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
          const SizedBox(height: PlaySpace.md),
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
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.friends, size: 48, color: colors.primary),
            const SizedBox(height: PlaySpace.md),
            Text(
              'No friends yet',
              style: PlayType.subtitle.copyWith(color: colors.ink),
            ),
            const SizedBox(height: PlaySpace.xs),
            Text(
              'Add people to your "friends" list to share your live location '
              'with them.',
              textAlign: TextAlign.center,
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.lg),
            PlayButton(
              label: 'Add friends',
              icon: PhosphorIconsRegular.userPlus,
              variant: PlayButtonVariant.soft,
              onPressed: () => context.push('/friends/manage'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PlaySpace.sm),
    child: Text(
      text,
      style: PlayType.overline.copyWith(color: PlayColors.of(context).inkMuted),
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
    final PlayColors colors = PlayColors.of(context);
    final LatLon? position = location?.position;
    String subtitle = 'Friend';
    if (position != null) {
      final String where = me == null
          ? 'Live'
          : 'Live · ${formatDistance(me.distanceTo(position), imperial: imperial)} away';
      subtitle = where;
    }
    return PlayRow(
      leading: FriendAvatar(
        label: friend.label,
        pictureUrl: friend.pictureUrl,
        borderColor: location == null ? null : const Color(0xFF1B9C6B),
      ),
      label: friend.label,
      subtitle: subtitle,
      showChevron: false,
      trailing: location == null
          ? null
          : Icon(PlayIcons.nearby, size: 18, color: colors.primary),
      onTap: () {
        if (location == null) {
          showPlayToast(context, '${friend.label} is not sharing right now');
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
