import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
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
    final ThemeData theme = Theme.of(context);
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
        return Material(
          color: theme.colorScheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _header(context, ref, label, friend, location),
              const SizedBox(height: AppSpacing.sm),
              if (location == null || !location.isLiveAt(DateTime.now()))
                _staleNotice(context)
              else ...<Widget>[
                _distanceRow(context, ref, location),
                const SizedBox(height: AppSpacing.sm),
                _shareWindow(context, location),
                const SizedBox(height: AppSpacing.md),
                _actions(context, ref, label, location),
                const SizedBox(height: AppSpacing.md),
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
    final ThemeData theme = Theme.of(context);
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
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: theme.textTheme.titleLarge),
              Text(
                live ? 'Updated just now' : 'Not sharing right now',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (live) const _LivePill(),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
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
    final ThemeData theme = Theme.of(context);
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
        Icon(
          Icons.near_me_outlined,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '${formatDistance(meters, imperial: imperial)} away'
            '${walkMinutes > 0 ? ' · About $walkMinutes min walk' : ''}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _shareWindow(BuildContext context, FriendLocation location) {
    final ThemeData theme = Theme.of(context);
    final int minutes = location.remainingMinutesAt(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sharing until ${formatClockTime(location.expiresAt)}'
              ' · ${minutes == 1 ? '1 min left' : '$minutes min left'}',
              style: theme.textTheme.bodyMedium,
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
          child: FilledButton.tonalIcon(
            onPressed: () => unawaited(_directions(ref, label, location)),
            icon: const Icon(Icons.directions),
            label: const Text('Directions'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => unawaited(_message(context, ref, label)),
            icon: const Icon(Icons.message_outlined),
            label: Text('Message $label'),
          ),
        ),
      ],
    );
  }

  Widget _messageHint(BuildContext context) => Text(
    'Messages are sent as private (gift-wrapped) Nostr direct messages.',
    style: Theme.of(context).textTheme.bodySmall,
  );

  Widget _staleNotice(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.location_off_outlined),
    title: const Text('This friend has stopped sharing'),
    subtitle: const Text('Their location is no longer visible.'),
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
        );
  }

  Future<void> _message(
    BuildContext context,
    WidgetRef ref,
    String label,
  ) async {
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _MessageDialog(label: label),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(socialServiceProvider)
          .sendDirectMessage(recipientPubkey: pubkey, text: text);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Message sent to $label')));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
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
            'Live',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageDialog extends StatefulWidget {
  const _MessageDialog({required this.label});

  final String label;

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Message ${widget.label}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 4000,
        decoration: const InputDecoration(
          hintText: 'Write a message',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
