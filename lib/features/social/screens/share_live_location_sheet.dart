import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/friend.dart';
import '../../../domain/entities/friend_location.dart';
import '../../../domain/entities/live_share.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/social.dart';
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';

/// Shows the "Let friends find you" sheet (who can see you, and for how long).
Future<void> showShareLiveLocationSheet(BuildContext context) {
  return showPlaySheet<void>(
    context,
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

  /// Guards the one-time application of the remembered choices, so a slow load
  /// never clobbers a selection the user already made.
  bool _userTouched = false;

  /// One key per duration chip, so the selected one can be scrolled into view
  /// (the row builds every chip eagerly, so the keys are always valid).
  late final List<GlobalKey> _durationKeys = List<GlobalKey>.generate(
    liveShareDurations.length,
    (_) => GlobalKey(),
  );
  bool _revealedSelection = false;

  static int get _defaultDurationIndex {
    final int index = liveShareDurations.indexWhere(
      (LiveShareDuration option) => option.duration == defaultLiveShareDuration,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restoreDefaults());
  }

  /// Pre-selects the last share's recipients and duration, once the friend list
  /// has loaded so a remembered pubkey that is no longer a friend is dropped.
  Future<void> _restoreDefaults() async {
    final LiveShareDefaults defaults = await ref
        .read(liveSharePreferencesProvider)
        .load();
    if (!mounted || _userTouched || defaults.isEmpty) {
      return;
    }
    final List<Friend> friends;
    try {
      friends = await ref.read(friendsProvider.future);
    } on Object {
      return;
    }
    if (!mounted || _userTouched) {
      return;
    }
    final Set<String> available = <String>{
      for (final Friend friend in friends) friend.pubkey,
    };
    final int index = liveShareDurations.indexWhere(
      (LiveShareDuration option) => option.duration == defaults.duration,
    );
    setState(() {
      _selected
        ..clear()
        ..addAll(defaults.recipients.where(available.contains));
      if (index >= 0) {
        _durationIndex = index;
      }
    });
    _revealSelectedDuration();
  }

  /// Scrolls the horizontal row so the selected duration is in view (e.g. a
  /// remembered 24-hour choice sits off the right edge of a phone).
  void _revealSelectedDuration() {
    if (!_revealedSelection) {
      _revealedSelection = true;
      _revealDuration(_durationIndex);
    }
  }

  void _revealDuration(int index) {
    final BuildContext? chipContext = _durationKeys[index].currentContext;
    if (chipContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      chipContext,
      alignment: 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool signedIn = ref.watch(socialServiceProvider).isLoggedIn;
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);
    final LiveShareState share = ref.watch(liveShareProvider);
    final Set<String> livePubkeys = <String>{
      for (final FriendLocation location in ref.watch(friendLocationsProvider))
        location.pubkey,
    };
    final Duration duration = liveShareDurations[_durationIndex].duration;
    final DateTime stopAt = DateTime.now().add(duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Let friends find you',
                  style: PlayType.headline.copyWith(
                    color: PlayColors.of(context).ink,
                  ),
                ),
                const SizedBox(height: PlaySpace.xs),
                Text(
                  'You choose who sees it and for how long.',
                  style: PlayType.body.copyWith(
                    color: PlayColors.of(context).inkMuted,
                  ),
                ),
                const SizedBox(height: PlaySpace.md),
                if (!signedIn)
                  _signedOutNotice(context)
                else ...<Widget>[
                  _sectionLabel(context, 'SHARE WITH', _selectionSummary()),
                  const SizedBox(height: PlaySpace.xs),
                  ..._friendRows(friends, livePubkeys),
                  const SizedBox(height: PlaySpace.md),
                  _sectionLabel(context, 'FOR HOW LONG?', null),
                  const SizedBox(height: PlaySpace.sm),
                  _durationRow(),
                  const SizedBox(height: PlaySpace.md),
                  Text(
                    'Sharing will stop automatically at '
                    '${formatClockTime(stopAt)}.',
                    style: PlayType.caption.copyWith(
                      color: PlayColors.of(context).inkMuted,
                    ),
                  ),
                  const SizedBox(height: PlaySpace.md),
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
              PlaySpace.lg,
              PlaySpace.sm,
              PlaySpace.lg,
              PlaySpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _consentNote(context, friends),
                const SizedBox(height: PlaySpace.sm),
                PlayButton(
                  label: _startLabel(),
                  icon: PhosphorIconsRegular.broadcast,
                  expand: true,
                  onPressed: _selected.isEmpty || _starting
                      ? null
                      : () => unawaited(_start(duration)),
                ),
                if (share.isActive) ...<Widget>[
                  const SizedBox(height: PlaySpace.xs),
                  PlayButton(
                    label: 'Stop sharing',
                    icon: PhosphorIconsRegular.stopCircle,
                    variant: PlayButtonVariant.ghost,
                    expand: true,
                    onPressed: () =>
                        unawaited(ref.read(liveShareProvider.notifier).stop()),
                  ),
                ],
              ],
            ),
          ),
      ],
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
    final PlayColors colors = PlayColors.of(context);
    return Row(
      children: <Widget>[
        Text(text, style: PlayType.overline.copyWith(color: colors.inkMuted)),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: PlayType.caption.copyWith(color: colors.inkMuted),
          ),
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
          padding: EdgeInsets.symmetric(vertical: PlaySpace.md),
          child: Center(child: PlaySpinner()),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        const PlayRow(
          icon: PlayIcons.error,
          label: 'Could not load your friends',
          subtitle: 'Check your connection and try again.',
          showChevron: false,
        ),
      ],
      data: (List<Friend> list) {
        if (list.isEmpty) {
          return <Widget>[
            const PlayRow(
              icon: PlayIcons.friends,
              label: 'No friends yet',
              subtitle:
                  'Add people to your friends list to share your location with '
                  'them.',
              showChevron: false,
            ),
          ];
        }
        return <Widget>[
          for (final Friend friend in list)
            PlayRow(
              leading: FriendAvatar(
                label: friend.label,
                pictureUrl: friend.pictureUrl,
                borderColor: livePubkeys.contains(friend.pubkey)
                    ? const Color(0xFF1B9C6B)
                    : null,
              ),
              label: friend.label,
              subtitle: livePubkeys.contains(friend.pubkey)
                  ? 'Sharing live with you'
                  : 'Friend',
              showChevron: false,
              trailing: _SelectionDot(
                selected: _selected.contains(friend.pubkey),
              ),
              onTap: _starting
                  ? null
                  : () => setState(() {
                      _userTouched = true;
                      if (_selected.contains(friend.pubkey)) {
                        _selected.remove(friend.pubkey);
                      } else {
                        _selected.add(friend.pubkey);
                      }
                    }),
            ),
        ];
      },
    );
  }

  Widget _durationRow() {
    // A horizontal strip so the five options stay on one line: when they do not
    // fit (a phone), the row scrolls instead of wrapping onto a second line.
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < liveShareDurations.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: PlaySpace.sm),
              PlayChip(
                key: _durationKeys[i],
                label: liveShareDurations[i].label,
                selected: _durationIndex == i,
                onTap: _starting ? null : () => _selectDuration(i),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectDuration(int index) {
    setState(() {
      _userTouched = true;
      _durationIndex = index;
    });
    _revealedSelection = true;
    _revealDuration(index);
  }

  Widget _consentNote(BuildContext context, AsyncValue<List<Friend>> friends) {
    final PlayColors colors = PlayColors.of(context);
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
    return PlaySurface(
      tone: PlayTone.sunken,
      radius: PlayRadii.md,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.all(PlaySpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(PlayIcons.lock, size: 20, color: colors.primary),
          const SizedBox(width: PlaySpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$who can see your location',
                  style: PlayType.body.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'The share is gift-wrap encrypted to each friend, and your '
                  'friends list is private. Anyone you do not select cannot see '
                  'it.',
                  style: PlayType.caption.copyWith(color: colors.inkMuted),
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
        const PlayRow(
          icon: PlayIcons.lock,
          label: 'Sign in to share your location',
          subtitle:
              'Live location is shared with friends over Nostr, encrypted to '
              'each of them.',
          showChevron: false,
        ),
        const SizedBox(height: PlaySpace.sm),
        PlayButton(label: 'Sign in with Nostr', onPressed: _openProfile),
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
      showPlayToast(context, 'You are sharing your live location');
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _starting = false);
      showPlayToast(context, error.message);
    }
  }
}

/// The trailing on/off marker on a selectable friend row.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Icon(
      selected ? PlayIcons.check : PlayIcons.dot,
      size: 24,
      color: selected ? colors.primary : colors.inkFaint,
    );
  }
}
