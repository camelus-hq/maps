import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/friend.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';

/// Manage the "friends" set (`/friends/manage`): who is in it, and who can be
/// added from the people the user already follows.
class ManageFriendsScreen extends ConsumerStatefulWidget {
  const ManageFriendsScreen({super.key});

  @override
  ConsumerState<ManageFriendsScreen> createState() =>
      _ManageFriendsScreenState();
}

class _ManageFriendsScreenState extends ConsumerState<ManageFriendsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    return PlayScaffold(
      appBar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PlayAppBar(title: 'Manage friends'),
          if (signedIn)
            PlayTabs(
              tabs: const <String>['Friends', 'Following'],
              selectedIndex: _tab,
              onSelected: (int index) => setState(() => _tab = index),
            ),
        ],
      ),
      child: !signedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(PlaySpace.xl),
                child: Text(
                  'Sign in with Nostr to manage your friends.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              children: <Widget>[
                _tab == 0 ? const _FriendsTab() : const _FollowingTab(),
                Positioned(
                  right: PlaySpace.lg,
                  bottom: PlaySpace.lg,
                  child: PlayButton(
                    label: 'Add friend',
                    icon: PhosphorIconsRegular.qrCode,
                    onPressed: () => context.push('/friends/add'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);
    return friends.when(
      loading: () => const Center(child: PlaySpinner()),
      error: (Object error, StackTrace stack) => _ErrorState(
        message: 'Could not load your friends',
        onRetry: () => ref.invalidate(friendsProvider),
      ),
      data: (List<Friend> list) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _PrivacyNote(),
            Expanded(
              child: list.isEmpty
                  ? const _EmptyState(
                      icon: PlayIcons.friends,
                      title: 'No friends yet',
                      body:
                          'Add people from the people you follow, or scan their '
                          'npub QR code. Only these people can see your live '
                          'location.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Friend friend = list[index];
                        return PlayRow(
                          leading: FriendAvatar(
                            label: friend.label,
                            pictureUrl: friend.pictureUrl,
                          ),
                          label: friend.label,
                          subtitle: _short(friend.pubkey),
                          showChevron: false,
                          trailing: PlayIconButton(
                            icon: PhosphorIconsRegular.userMinus,
                            variant: PlayIconButtonVariant.plain,
                            size: 40,
                            semanticLabel: 'Remove',
                            onPressed: () =>
                                unawaited(_remove(context, ref, friend)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    final bool confirmed =
        await showPlaySheet<bool>(
          context,
          builder: (BuildContext context) =>
              _RemoveConfirm(label: friend.label),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(commandRegistryProvider).dispatch(
        'social.friend.remove',
        <String, Object?>{'pubkey': friend.pubkey},
      );
      if (context.mounted) {
        showPlayToast(context, 'Removed ${friend.label}');
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showPlayToast(context, error.message);
      }
    }
  }
}

/// Confirmation sheet for removing a friend; pops `true` on confirm.
class _RemoveConfirm extends StatelessWidget {
  const _RemoveConfirm({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.lg,
        0,
        PlaySpace.lg,
        PlaySpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Remove $label?',
            style: PlayType.title.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(
            'They will no longer be able to see your live location.',
            style: PlayType.body.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: PlayButton(
                  label: 'Cancel',
                  variant: PlayButtonVariant.ghost,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: PlaySpace.sm),
              Expanded(
                child: PlayButton(
                  label: 'Remove',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowingTab extends ConsumerStatefulWidget {
  const _FollowingTab();

  @override
  ConsumerState<_FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends ConsumerState<_FollowingTab> {
  final TextEditingController _filter = TextEditingController();
  final Set<String> _busy = <String>{};

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Friend>> followings = ref.watch(followingsProvider);
    final Set<String> friends = <String>{
      for (final Friend friend
          in ref.watch(friendsProvider).value ?? const <Friend>[])
        friend.pubkey,
    };
    final String query = _filter.text.trim().toLowerCase();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PlaySpace.lg,
            PlaySpace.sm,
            PlaySpace.lg,
            PlaySpace.xs,
          ),
          child: PlayTextField(
            controller: _filter,
            hint: 'Filter people you follow',
            leading: const Icon(PlayIcons.search),
            onChanged: (String _) => setState(() {}),
          ),
        ),
        Expanded(
          child: followings.when(
            loading: () => const Center(child: PlaySpinner()),
            error: (Object error, StackTrace stack) => _ErrorState(
              message: 'Could not load who you follow',
              onRetry: () => ref.invalidate(followingsProvider),
            ),
            data: (List<Friend> list) {
              final List<Friend> visible = <Friend>[
                for (final Friend friend in list)
                  if (query.isEmpty ||
                      friend.label.toLowerCase().contains(query) ||
                      friend.pubkey.contains(query))
                    friend,
              ];
              if (visible.isEmpty) {
                return _EmptyState(
                  icon: PhosphorIconsRegular.users,
                  title: list.isEmpty
                      ? 'You do not follow anyone yet'
                      : 'No matches',
                  body: list.isEmpty
                      ? 'Follow people on Nostr first, then add them here.'
                      : 'Try a different name or key.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) {
                  final Friend friend = visible[index];
                  final bool added = friends.contains(friend.pubkey);
                  return PlayRow(
                    leading: FriendAvatar(
                      label: friend.label,
                      pictureUrl: friend.pictureUrl,
                    ),
                    label: friend.label,
                    subtitle: _short(friend.pubkey),
                    showChevron: false,
                    trailing: added
                        ? Text(
                            'Added',
                            style: PlayType.caption.copyWith(
                              color: PlayColors.of(context).inkMuted,
                            ),
                          )
                        : _busy.contains(friend.pubkey)
                        ? const PlaySpinner(size: 20, strokeWidth: 2)
                        : PlayButton(
                            label: 'Add',
                            variant: PlayButtonVariant.soft,
                            size: PlayButtonSize.sm,
                            onPressed: () => unawaited(_add(context, friend)),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, Friend friend) async {
    setState(() => _busy.add(friend.pubkey));
    try {
      await ref.read(commandRegistryProvider).dispatch(
        'social.friend.add',
        <String, Object?>{'pubkey': friend.pubkey},
      );
      if (context.mounted) {
        showPlayToast(context, 'Added ${friend.label}');
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showPlayToast(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(friend.pubkey));
      }
    }
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.lg,
        PlaySpace.sm,
        PlaySpace.lg,
        PlaySpace.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(PlayIcons.lock, size: 18, color: colors.primary),
          const SizedBox(width: PlaySpace.sm),
          Expanded(
            child: Text(
              'Only you can see this list. It is stored encrypted in your own '
              'Nostr set, so relays never learn who your friends are.',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: colors.primary),
            const SizedBox(height: PlaySpace.md),
            Text(title, style: PlayType.subtitle.copyWith(color: colors.ink)),
            const SizedBox(height: PlaySpace.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.error, color: colors.ink),
            const SizedBox(height: PlaySpace.sm),
            Text(message, style: PlayType.body.copyWith(color: colors.ink)),
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
}

String _short(String pubkey) =>
    pubkey.length <= 16 ? pubkey : '${pubkey.substring(0, 10)}…';
