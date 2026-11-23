import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../domain/entities/trip.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/settings.dart';
import '../../../state/trips.dart';
import '../../design/play.dart';

/// Lists the recorded trips (newest first); tapping one opens its detail page,
/// where it can be reviewed and exported as GPX.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Trip> trips = ref.watch(recentTripsProvider);
    final bool recordingOff = !ref.watch(settingsProvider).tripRecordingEnabled;
    final Widget body = trips.isEmpty
        ? _Empty(recordingOff: recordingOff)
        : ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: PlaySpace.lg,
              vertical: PlaySpace.sm,
            ),
            itemCount: trips.length,
            separatorBuilder: (BuildContext context, int index) =>
                const PlayDivider(),
            itemBuilder: (BuildContext context, int index) {
              final Trip trip = trips[index];
              return PlayRow(
                leading: PlaySurface(
                  tone: PlayTone.soft,
                  radius: PlayRadii.sm,
                  shadow: PlayShadow.none,
                  padding: const EdgeInsets.all(PlaySpace.sm),
                  child: Icon(
                    _modeIcon(trip),
                    size: 20,
                    color: PlayColors.of(context).onPrimarySoft,
                  ),
                ),
                label: trip.title,
                subtitle: _subtitle(context, ref, trip),
                onTap: () => context.push('/trips/${trip.id}'),
                trailing: PlayIconButton(
                  icon: PlayIcons.close,
                  variant: PlayIconButtonVariant.plain,
                  size: 40,
                  semanticLabel: 'Delete trip',
                  onPressed: () => unawaited(
                    ref.read(recentTripsProvider.notifier).delete(trip.id),
                  ),
                ),
              );
            },
          );
    return PlayScaffold(
      appBar: const PlayAppBar(title: 'Recent trips'),
      child: Column(
        children: <Widget>[
          if (recordingOff) const _RecordingOffBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }

  static IconData _modeIcon(Trip trip) => switch (trip.mode) {
    TravelMode.walk => PlayIcons.directions,
    TravelMode.drive => PlayIcons.navigation,
    TravelMode.cycle => PlayIcons.route,
    TravelMode.transit => PlayIcons.directions,
  };
}

/// The subtitle: when it happened, how far and how long.
String _subtitle(BuildContext context, WidgetRef ref, Trip trip) {
  final bool imperial = ref.watch(imperialUnitsProvider);
  return <String>[
    formatTimeAgo(trip.startedAt),
    formatDistance(trip.distanceMeters, imperial: imperial),
    formatDuration(trip.duration),
  ].join(' · ');
}

class _Empty extends StatelessWidget {
  const _Empty({required this.recordingOff});

  final bool recordingOff;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(PlayIcons.route, size: 44, color: colors.inkFaint),
          const SizedBox(height: PlaySpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PlaySpace.xl),
            child: Text(
              recordingOff
                  ? 'No trips recorded yet. Turn recording on to save the '
                        'routes you navigate.'
                  : 'No trips yet. Start navigation and your route is recorded '
                        'here.',
              textAlign: TextAlign.center,
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The banner shown at the top of the trips page while recording is off: it
/// explains the state and offers to turn it back on.
class _RecordingOffBanner extends ConsumerWidget {
  const _RecordingOffBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.lg,
        PlaySpace.sm,
        PlaySpace.lg,
        0,
      ),
      child: PlaySurface(
        tone: PlayTone.soft,
        shadow: PlayShadow.none,
        padding: const EdgeInsets.all(PlaySpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(PlayIcons.route, size: 22, color: colors.onPrimarySoft),
                const SizedBox(width: PlaySpace.sm),
                Expanded(
                  child: Text(
                    'Trip recording is off',
                    style: PlayType.title.copyWith(color: colors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PlaySpace.xs),
            Text(
              'New trips are not saved. Turn recording back on to keep the '
              'routes you navigate.',
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: PlayButton(
                label: 'Turn on trip recording',
                icon: PlayIcons.navigation,
                size: PlayButtonSize.sm,
                onPressed: () => unawaited(
                  ref
                      .read(commandRegistryProvider)
                      .dispatch(
                        'trips.recording.enable',
                        const <String, Object?>{},
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
