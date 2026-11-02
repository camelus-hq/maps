import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/friend.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../widgets/friend_avatar.dart';

/// Manage the "friends" set (`/friends/manage`): who is in it, and who can be
/// added from the people the user already follows.
class ManageFriendsScreen extends ConsumerWidget {
  const ManageFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage friends'),
          bottom: signedIn
              ? const TabBar(
                  tabs: <Widget>[
                    Tab(text: 'Friends'),
                    Tab(text: 'Following'),
                  ],
                )
              : null,
        ),
        floatingActionButton: signedIn
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/friends/add'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Add friend'),
              )
            : null,
        body: SafeArea(
          child: !signedIn
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Sign in with Nostr to manage your friends.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const TabBarView(
                  children: <Widget>[_FriendsTab(), _FollowingTab()],
                ),
        ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
                      icon: Icons.people_outline,
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
                        return ListTile(
                          leading: FriendAvatar(
                            label: friend.label,
                            pictureUrl: friend.pictureUrl,
                          ),
                          title: Text(friend.label),
                          subtitle: Text(_short(friend.pubkey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove_outlined),
                            tooltip: 'Remove',
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
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Remove ${friend.label}?'),
            content: const Text(
              'They will no longer be able to see your live location.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Removed ${friend.label}')));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
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
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: TextField(
            controller: _filter,
            onChanged: (String _) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Filter people you follow',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: followings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
                  icon: Icons.group_outlined,
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
                  return ListTile(
                    leading: FriendAvatar(
                      label: friend.label,
                      pictureUrl: friend.pictureUrl,
                    ),
                    title: Text(friend.label),
                    subtitle: Text(_short(friend.pubkey)),
                    trailing: added
                        ? const Text('Added')
                        : _busy.contains(friend.pubkey)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FilledButton.tonal(
                            onPressed: () => unawaited(_add(context, friend)),
                            child: const Text('Add'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Added ${friend.label}')));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
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
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Only you can see this list. It is stored encrypted in your own '
              'Nostr set, so relays never learn who your friends are.',
              style: theme.textTheme.bodySmall,
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
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline),
            const SizedBox(height: AppSpacing.sm),
            Text(message),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _short(String pubkey) =>
    pubkey.length <= 16 ? pubkey : '${pubkey.substring(0, 10)}…';
