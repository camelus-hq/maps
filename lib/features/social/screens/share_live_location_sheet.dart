import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/friend.dart';
import '../../../domain/entities/friend_location.dart';
import '../../../domain/entities/live_share.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../widgets/friend_avatar.dart';

/// Shows the "Let friends find you" sheet (who can see you, and for how long).
Future<void> showShareLiveLocationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const ShareLiveLocationSheet(),
  );
}

/// Bottom sheet for starting a live-location share.
///
/// Nothing is selected by default (sharing is opt-in, mirroring the reference
/// app's "you choose who sees it and for how long"). Starting runs the same
/// `social.share.start` command the control channel uses.
class ShareLiveLocationSheet extends ConsumerStatefulWidget {
  const ShareLiveLocationSheet({super.key});

  @override
  ConsumerState<ShareLiveLocationSheet> createState() =>
      _ShareLiveLocationSheetState();
}

class _ShareLiveLocationSheetState
    extends ConsumerState<ShareLiveLocationSheet> {
  final Set<String> _selected = <String>{};
  int _durationIndex = _defaultDurationIndex;
  bool _starting = false;

  static int get _defaultDurationIndex {
    final int index = liveShareDurations.indexWhere(
      (LiveShareDuration option) => option.duration == defaultLiveShareDuration,
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);
    final LiveShareState share = ref.watch(liveShareProvider);
    final Set<String> livePubkeys = <String>{
      for (final FriendLocation location in ref.watch(friendLocationsProvider))
        location.pubkey,
    };
    final Duration duration = liveShareDurations[_durationIndex].duration;
    final DateTime stopAt = DateTime.now().add(duration);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Leave room for the sticky footer even on a small screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Let friends find you',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'You choose who sees it and for how long.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!signedIn)
                      _signedOutNotice(context)
                    else ...<Widget>[
                      _sectionLabel(context, 'SHARE WITH', _selectionSummary()),
                      const SizedBox(height: AppSpacing.xs),
                      ..._friendRows(friends, livePubkeys),
                      const SizedBox(height: AppSpacing.md),
                      _sectionLabel(context, 'FOR HOW LONG?', null),
                      const SizedBox(height: AppSpacing.sm),
                      _durationRow(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Sharing will stop automatically at '
                        '${formatClockTime(stopAt)}.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
            // Sticky footer: the consent note and the action stay put while the
            // friend list scrolls.
            if (signedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _consentNote(context, friends),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty || _starting
                          ? null
                          : () => unawaited(_start(duration)),
                      icon: _starting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_location_outlined),
                      label: Text(_startLabel()),
                    ),
                    if (share.isActive) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: () => unawaited(
                          ref.read(liveShareProvider.notifier).stop(),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop sharing'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _selectionSummary() {
    if (_selected.isEmpty) {
      return 'None selected';
    }
    return '${_selected.length} selected';
  }

  String _startLabel() {
    final int count = _selected.length;
    if (count == 0) {
      return 'Select friends to share with';
    }
    return count == 1
        ? 'Share live with 1 friend'
        : 'Share live with $count friends';
  }

  Widget _sectionLabel(BuildContext context, String text, String? trailing) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (trailing != null) Text(trailing, style: theme.textTheme.bodySmall),
      ],
    );
  }

  List<Widget> _friendRows(
    AsyncValue<List<Friend>> friends,
    Set<String> livePubkeys,
  ) {
    return friends.when(
      loading: () => <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.error_outline),
          title: Text('Could not load your friends'),
          subtitle: Text('Check your connection and try again.'),
        ),
      ],
      data: (List<Friend> list) {
        if (list.isEmpty) {
          return <Widget>[
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.people_outline),
              title: Text('No friends yet'),
              subtitle: Text(
                'Add people to your friends list to share your location with '
                'them.',
              ),
            ),
          ];
        }
        return <Widget>[
          for (final Friend friend in list)
            CheckboxListTile(
              value: _selected.contains(friend.pubkey),
              onChanged: _starting
                  ? null
                  : (bool? checked) => setState(() {
                      if (checked == true) {
                        _selected.add(friend.pubkey);
                      } else {
                        _selected.remove(friend.pubkey);
                      }
                    }),
              controlAffinity: ListTileControlAffinity.trailing,
              contentPadding: EdgeInsets.zero,
              secondary: FriendAvatar(
                label: friend.label,
                pictureUrl: friend.pictureUrl,
                borderColor: livePubkeys.contains(friend.pubkey)
                    ? const Color(0xFF1B9C6B)
                    : null,
              ),
              title: Text(friend.label),
              subtitle: Text(
                livePubkeys.contains(friend.pubkey)
                    ? 'Sharing live with you'
                    : 'Friend',
              ),
            ),
        ];
      },
    );
  }

  Widget _durationRow() {
    return Wrap(
      spacing: AppSpacing.sm,
      children: <Widget>[
        for (int i = 0; i < liveShareDurations.length; i++)
          ChoiceChip(
            label: Text(liveShareDurations[i].label),
            selected: _durationIndex == i,
            onSelected: _starting
                ? null
                : (bool _) => setState(() => _durationIndex = i),
          ),
      ],
    );
  }

  Widget _consentNote(BuildContext context, AsyncValue<List<Friend>> friends) {
    final ThemeData theme = Theme.of(context);
    final List<String> names = <String>[
      for (final Friend friend in friends.value ?? const <Friend>[])
        if (_selected.contains(friend.pubkey)) friend.label,
    ];
    final String who;
    if (names.isEmpty) {
      who = 'Nobody yet';
    } else if (names.length == 1) {
      who = 'Only ${names.first}';
    } else {
      final String head = names.take(2).join(' and ');
      who = names.length > 2
          ? 'Only $head and ${names.length - 2} more'
          : 'Only $head';
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$who can see your location',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'The share is gift-wrap encrypted to each friend, and your '
                  'friends list is private. Anyone you do not select cannot see '
                  'it.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutNotice(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('Sign in to share your location'),
          subtitle: Text(
            'Live location is shared with friends over Nostr, encrypted to each '
            'of them.',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _openProfile,
          child: const Text('Sign in with Nostr'),
        ),
      ],
    );
  }

  void _openProfile() {
    final GoRouter router = GoRouter.of(context);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    router.push('/profile');
  }

  Future<void> _start(Duration duration) async {
    setState(() => _starting = true);
    try {
      await ref.read(commandRegistryProvider).dispatch(
        'social.share.start',
        <String, Object?>{
          'recipients': _selected.toList(growable: false),
          'durationMinutes': duration.inMinutes,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => _starting = false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are sharing your live location')),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _starting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
