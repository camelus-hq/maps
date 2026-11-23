import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../domain/entities/trip.dart';
import '../../../domain/usecases/trip_gpx.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/settings.dart';
import '../../../state/trips.dart';
import '../../common/navigation.dart';
import '../../design/play.dart';
import '../widgets/trip_track_preview.dart';

/// One recorded trip: its tracked path, its stats, and an "Export GPX" action.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Trip> trips = ref.watch(recentTripsProvider);
    final Trip? current = _tripById(trips, tripId);
    return PlayScaffold(
      appBar: PlayAppBar(
        title: 'Trip',
        subtitle: current == null ? null : formatTimeAgo(current.startedAt),
      ),
      child: current == null ? const _Missing() : _TripBody(trip: current),
    );
  }
}

/// The trip with [id], or `null` when it is no longer in the list.
Trip? _tripById(List<Trip> trips, String id) {
  for (final Trip trip in trips) {
    if (trip.id == id) {
      return trip;
    }
  }
  return null;
}

class _TripBody extends ConsumerWidget {
  const _TripBody({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final PlayColors colors = PlayColors.of(context);
    final String? origin = trip.originName;
    final String? destination = trip.destinationName;
    final String route = <String>[
      if (origin != null && origin.trim().isNotEmpty) origin,
      if (destination != null && destination.trim().isNotEmpty) destination,
    ].join('  →  ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.lg,
        PlaySpace.sm,
        PlaySpace.lg,
        PlaySpace.xxl,
      ),
      children: <Widget>[
        TripTrackPreview(track: trip.track),
        const SizedBox(height: PlaySpace.lg),
        if (route.isNotEmpty) ...<Widget>[
          Text(route, style: PlayType.title.copyWith(color: colors.ink)),
          const SizedBox(height: PlaySpace.md),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: PlayStatCard(
                  value: formatDistance(
                    trip.distanceMeters,
                    imperial: imperial,
                  ),
                  label: 'Distance',
                  tone: PlayTone.mint,
                  icon: PlayIcons.route,
                ),
              ),
              const SizedBox(width: PlaySpace.md),
              Expanded(
                child: PlayStatCard(
                  value: formatDuration(trip.duration),
                  label: 'Duration',
                  tone: PlayTone.soft,
                  icon: PlayIcons.clock,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PlaySpace.md),
        PlayRow(
          icon: PlayIcons.route,
          label: 'Recorded points',
          subtitle: '${trip.track.length}',
          showChevron: false,
        ),
        const SizedBox(height: PlaySpace.lg),
        PlayButton(
          label: 'Export GPX',
          icon: PlayIcons.download,
          expand: true,
          onPressed: () => unawaited(_export(context, ref, trip)),
        ),
        const SizedBox(height: PlaySpace.sm),
        PlayButton(
          label: 'Delete trip',
          icon: PlayIcons.close,
          variant: PlayButtonVariant.ghost,
          expand: true,
          onPressed: () => unawaited(_delete(context, ref, trip)),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, Trip trip) async {
    String? path;
    String? error;
    try {
      final Object? result = await ref.read(commandRegistryProvider).dispatch(
        'trips.export',
        <String, Object?>{'id': trip.id},
      );
      if (result is Map) {
        final Object? rawPath = result['path'];
        path = rawPath is String ? rawPath : null;
        final Object? rawError = result['error'];
        error = rawError is String ? rawError : null;
      }
    } catch (_) {
      error = 'export failed';
    }
    // The GPX text is always available, so copy it to the clipboard too — the
    // most useful fallback when the platform has no handy file location.
    try {
      await Clipboard.setData(ClipboardData(text: TripGpx.encode(trip)));
    } catch (_) {
      // Clipboard is best-effort (and unavailable in plain unit tests).
    }
    if (!context.mounted) {
      return;
    }
    if (path != null) {
      showPlayToast(context, 'GPX exported to $path');
    } else if (error != null) {
      showPlayToast(
        context,
        'Saved to the clipboard (file export unavailable)',
      );
    } else {
      showPlayToast(context, 'GPX copied to the clipboard');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Trip trip) async {
    await ref.read(recentTripsProvider.notifier).delete(trip.id);
    if (context.mounted) {
      popOrHome(context);
    }
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Text(
        'This trip is no longer available',
        style: PlayType.body.copyWith(color: colors.inkMuted),
      ),
    );
  }
}
