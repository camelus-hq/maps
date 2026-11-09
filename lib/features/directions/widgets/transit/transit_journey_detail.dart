import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/commands/commands_provider.dart';
import '../../../../state/route.dart';
import '../../../../state/settings.dart';
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
              const _DragHandle(),
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
                              Icons.chevron_right,
                              size: 18,
                              color: scheme.outline,
                            ),
                          TransitLineBadge(leg: rides[i]),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
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
              const Divider(height: AppSpacing.md),
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

/// The grab handle at the top of the detail sheet.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Row(
        children: <Widget>[
          FilledButton.icon(
            onPressed: () => unawaited(
              ref
                  .read(commandRegistryProvider)
                  .dispatch('transit.navigate', const <String, Object?>{}),
            ),
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            icon: const Icon(Icons.navigation),
            label: const Text('Start'),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatDuration(itinerary.duration),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                transitClock(context, itinerary.endTime.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
