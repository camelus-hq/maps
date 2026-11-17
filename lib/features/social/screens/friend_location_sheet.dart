import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/friend.dart';
import '../../../domain/entities/friend_location.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../state/ports.dart';
import '../../../state/route.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../../state/social.dart';
import '../../common/map_sheet.dart';
import '../../design/play.dart';
import '../widgets/friend_avatar.dart';

/// Bottom sheet for a friend's live location.
///
/// Mirrors the reference app's friend card: who it is, how far away they are,
/// when the share ends, and actions to get directions or message them.
class FriendLocationSheet extends ConsumerWidget {
  const FriendLocationSheet({super.key, required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FriendLocation? location = _locationFor(ref);
    final Friend? friend = ref.watch(friendsByPubkeyProvider)[pubkey];
    final String label = friend?.label ?? location?.label ?? _short(pubkey);

    return MapSheet(
      initialChildSize: 0.42,
      minChildSize: 0.42,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const <double>[0.42, 0.9],
      builder: (BuildContext context, ScrollController scrollController) {
        return PlaySheet(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.lg,
              0,
              PlaySpace.lg,
              PlaySpace.xl,
            ),
            children: <Widget>[
              const PlaySheetHandle(),
              _header(context, ref, label, friend, location),
              const SizedBox(height: PlaySpace.sm),
              if (location == null || !location.isLiveAt(DateTime.now()))
                _staleNotice(context)
              else ...<Widget>[
                _distanceRow(context, ref, location),
                const SizedBox(height: PlaySpace.sm),
                _shareWindow(context, location),
                const SizedBox(height: PlaySpace.md),
                _actions(context, ref, label, location),
                const SizedBox(height: PlaySpace.md),
                _messageHint(context),
              ],
            ],
          ),
        );
      },
    );
  }

  FriendLocation? _locationFor(WidgetRef ref) {
    for (final FriendLocation location in ref.watch(friendLocationsProvider)) {
      if (location.pubkey == pubkey) {
        return location;
      }
    }
    return null;
  }

  Widget _header(
    BuildContext context,
    WidgetRef ref,
    String label,
    Friend? friend,
    FriendLocation? location,
  ) {
    final PlayColors colors = PlayColors.of(context);
    final bool live = location?.isLiveAt(DateTime.now()) ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FriendAvatar(
          label: label,
          pictureUrl: friend?.pictureUrl ?? location?.pictureUrl,
          size: 48,
          borderColor: live ? const Color(0xFF1B9C6B) : null,
        ),
        const SizedBox(width: PlaySpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: PlayType.title.copyWith(color: colors.ink)),
              Text(
                live ? 'Updated just now' : 'Not sharing right now',
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
        if (live) const _LivePill(),
        PlayIconButton(
          icon: PlayIcons.close,
          variant: PlayIconButtonVariant.plain,
          size: 40,
          semanticLabel: 'Close',
          onPressed: () => ref.read(selectedFriendProvider.notifier).clear(),
        ),
      ],
    );
  }

  Widget _distanceRow(
    BuildContext context,
    WidgetRef ref,
    FriendLocation location,
  ) {
    final PlayColors colors = PlayColors.of(context);
    final LatLon? me = ref.watch(userLocationProvider).value;
    final LatLon? position = location.position;
    if (me == null || position == null) {
      return const SizedBox.shrink();
    }
    final bool imperial = ref.watch(imperialUnitsProvider);
    final double meters = me.distanceTo(position);
    final int walkMinutes = (meters / 80).ceil();
    return Row(
      children: <Widget>[
        Icon(PlayIcons.nearby, size: 18, color: colors.primary),
        const SizedBox(width: PlaySpace.xs),
        Expanded(
          child: Text(
            '${formatDistance(meters, imperial: imperial)} away'
            '${walkMinutes > 0 ? ' · About $walkMinutes min walk' : ''}',
            style: PlayType.body.copyWith(color: colors.ink),
          ),
        ),
      ],
    );
  }

  Widget _shareWindow(BuildContext context, FriendLocation location) {
    final PlayColors colors = PlayColors.of(context);
    final int minutes = location.remainingMinutesAt(DateTime.now());
    return PlaySurface(
      tone: PlayTone.sunken,
      radius: PlayRadii.md,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.symmetric(
        horizontal: PlaySpace.sm,
        vertical: PlaySpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(PlayIcons.clock, size: 18, color: colors.inkMuted),
          const SizedBox(width: PlaySpace.sm),
          Expanded(
            child: Text(
              'Sharing until ${formatClockTime(location.expiresAt)}'
              ' · ${minutes == 1 ? '1 min left' : '$minutes min left'}',
              style: PlayType.body.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    String label,
    FriendLocation location,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: PlayButton(
            label: 'Directions',
            icon: PlayIcons.directions,
            variant: PlayButtonVariant.soft,
            expand: true,
            onPressed: () => unawaited(_directions(ref, label, location)),
          ),
        ),
        const SizedBox(width: PlaySpace.sm),
        Expanded(
          child: PlayButton(
            label: 'Message $label',
            icon: PhosphorIconsRegular.chatCircle,
            variant: PlayButtonVariant.ghost,
            expand: true,
            onPressed: () => unawaited(_message(context, ref, label)),
          ),
        ),
      ],
    );
  }

  Widget _messageHint(BuildContext context) => Text(
    'Messages are sent as private (gift-wrapped) Nostr direct messages.',
    style: PlayType.caption.copyWith(color: PlayColors.of(context).inkMuted),
  );

  Widget _staleNotice(BuildContext context) => const PlayRow(
    icon: PlayIcons.locationLost,
    label: 'This friend has stopped sharing',
    subtitle: 'Their location is no longer visible.',
    showChevron: false,
  );

  Future<void> _directions(
    WidgetRef ref,
    String label,
    FriendLocation location,
  ) async {
    final LatLon? position = location.position;
    if (position == null) {
      return;
    }
    ref.read(selectedFriendProvider.notifier).clear();
    await ref
        .read(routeControllerProvider.notifier)
        .plan(
          Place(
            id: 'friend:$pubkey',
            name: label,
            position: position,
            category: 'Live location',
          ),
          suggestMode: true,
        );
  }

  Future<void> _message(
    BuildContext context,
    WidgetRef ref,
    String label,
  ) async {
    final String? text = await showPlaySheet<String>(
      context,
      builder: (BuildContext context) => _MessageSheet(label: label),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(socialServiceProvider)
          .sendDirectMessage(recipientPubkey: pubkey, text: text);
      if (context.mounted) {
        showPlayToast(context, 'Message sent to $label');
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showPlayToast(context, error.message);
      }
    }
  }

  static String _short(String pubkey) =>
      pubkey.length <= 14 ? pubkey : '${pubkey.substring(0, 10)}…';
}

class _LivePill extends StatelessWidget {
  const _LivePill();

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
            'Live',
            style: PlayType.caption.copyWith(
              color: colors.onPrimarySoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Message …" composer, shown from the friend sheet.
class _MessageSheet extends StatefulWidget {
  const _MessageSheet({required this.label});

  final String label;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            'Message ${widget.label}',
            style: PlayType.title.copyWith(color: colors.ink),
          ),
          const SizedBox(height: PlaySpace.md),
          PlayTextField(
            controller: _controller,
            hint: 'Write a message',
            autofocus: true,
          ),
          const SizedBox(height: PlaySpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: PlayButton(
                  label: 'Cancel',
                  variant: PlayButtonVariant.ghost,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: PlaySpace.sm),
              Expanded(
                child: PlayButton(
                  label: 'Send',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(_controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
