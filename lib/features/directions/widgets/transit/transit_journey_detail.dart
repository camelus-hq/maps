import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/commands/commands_provider.dart';
import '../../../../state/route.dart';
import '../../../../state/settings.dart';
import '../../../design/play.dart';
import 'transit_common.dart';
import 'transit_line_badge.dart';
import 'transit_timeline.dart';

/// Step 2: the full journey detail — a line-badge header, the leg-by-leg
/// timeline (with platforms/tracks, wait times and delays) and a footer that
/// sticks to the bottom with the Start action, the total duration and the
/// arrival time.
class TransitJourneyDetail extends ConsumerWidget {
  const TransitJourneyDetail({
    super.key,
    required this.itinerary,
    required this.scrollController,
  });

  final TransitItinerary itinerary;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    final bool imperial = ref.watch(imperialUnitsProvider);
    final RouteState routeState = ref.watch(routeControllerProvider);
    final List<TransitLeg> rides = itinerary.rides;
    final String originName =
        routeState.origin?.name ?? itinerary.originStop?.name ?? 'Start';
    final String destinationName =
        routeState.destination?.name ??
        itinerary.destinationStop?.name ??
        'Destination';
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            children: <Widget>[
              // The grab handle is part of the scrollable so it — and the badge
              // header — can drag the sheet at any size, including the peek.
              const PlaySheetHandle(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < rides.length; i++) ...<Widget>[
                          if (i > 0)
                            Icon(
                              PlayIcons.next,
                              size: 18,
                              color: colors.inkFaint,
                            ),
                          TransitLineBadge(leg: rides[i]),
                        ],
                      ],
                    ),
                  ),
                  PlayIconButton(
                    icon: PlayIcons.close,
                    variant: PlayIconButtonVariant.plain,
                    size: 40,
                    semanticLabel: 'Close',
                    onPressed: () => unawaited(
                      ref
                          .read(commandRegistryProvider)
                          .dispatch(
                            'transit.detail.close',
                            const <String, Object?>{},
                          ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: PlayDivider(),
              ),
              TransitTimeline(
                itinerary: itinerary,
                originName: originName,
                destinationName: destinationName,
                imperial: imperial,
                onStopTap: (TransitStop stop) => _openDepartures(ref, stop),
              ),
            ],
          ),
        ),
        _DetailFooter(itinerary: itinerary),
      ],
    );
  }

  void _openDepartures(WidgetRef ref, TransitStop stop) {
    final String? id = stop.id?.trim();
    if (id == null || id.isEmpty) {
      return;
    }
    unawaited(
      ref.read(commandRegistryProvider).dispatch('transit.departures', {
        'stopId': id,
        'name': stop.name,
      }),
    );
  }
}

/// The sticky bottom bar: a pill Start button, the journey's duration and its
/// arrival time.
class _DetailFooter extends ConsumerWidget {
  const _DetailFooter({required this.itinerary});

  final TransitItinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Row(
          children: <Widget>[
            PlayButton(
              label: 'Start',
              icon: PlayIcons.navigation,
              onPressed: () => unawaited(
                ref
                    .read(commandRegistryProvider)
                    .dispatch('transit.navigate', const <String, Object?>{}),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatDuration(itinerary.duration),
                  style: PlayType.subtitle.copyWith(color: colors.ink),
                ),
                Text(
                  transitClock(context, itinerary.endTime.toLocal()),
                  style: PlayType.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
