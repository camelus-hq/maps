import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/navigation.dart';
import '../../../state/route.dart';
import '../../../state/settings.dart';
import '../../directions/widgets/transit/transit_line_badge.dart';
import '../../directions/widgets/transit/transit_timeline.dart';
import 'nav_sheet.dart';

/// The public-transport navigation sheet.
///
/// It shows the journey as the reference does: the leg-by-leg timeline with a
/// **live indicator** (the navigation arrow) marking where the traveller
/// currently is, so the whole trip — what has happened, what is happening now
/// and what is next — is readable at a glance. Tapping a station opens its
/// departures board.
class TransitNavBottomSheet extends ConsumerWidget {
  const TransitNavBottomSheet({
    super.key,
    required this.nav,
    required this.tracking,
    required this.onExit,
    required this.onToggleOverview,
  });

  final NavState nav;
  final bool tracking;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final TransitItinerary? itinerary = nav.transit;
    final TransitProgress? progress = nav.transitProgress;
    // Prefer the endpoint names the user chose over the provider's fallback
    // ("START"/"END") so the timeline reads with the real places.
    final RouteState routeState = ref.watch(routeControllerProvider);
    return NavSheet(
      nav: nav,
      tracking: tracking,
      onExit: onExit,
      onToggleOverview: onToggleOverview,
      initialChildSize: 0.42,
      minChildSize: 0.14,
      maxChildSize: 0.8,
      snapSizes: const <double>[0.14, 0.42, 0.8],
      body: itinerary == null
          ? _fallback(context, ref, nav)
          : _timeline(
              context,
              ref,
              nav,
              itinerary,
              progress,
              imperial,
              routeState,
            ),
    );
  }

  /// The journey fallback when a transit session has no itinerary attached
  /// (a programmatic `nav.start` in transit mode): the arrival-led summary the
  /// sheet showed before the journey timeline.
  Widget _fallback(BuildContext context, WidgetRef ref, NavState nav) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final double remaining = (nav.totalMeters - nav.traveledMeters).clamp(
      0,
      double.infinity,
    );
    final (String, String) timeText = splitUnit(formatDuration(nav.remaining));
    final (String, String) remainingText = splitUnit(
      formatDistance(remaining, imperial: imperial),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NavStatsRow(
            stats: <NavStat>[
              NavStat(arrivalLabel(context, nav.remaining), '', 'Arrives'),
              NavStat(timeText.$1, timeText.$2, 'Time left'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.directions_transit,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Public transport • ${remainingText.$1} ${remainingText.$2} '
                  'to go',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeline(
    BuildContext context,
    WidgetRef ref,
    NavState nav,
    TransitItinerary itinerary,
    TransitProgress? progress,
    bool imperial,
    RouteState routeState,
  ) {
    final List<TransitLeg> rides = itinerary.rides;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          if (rides.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    TransitLineBadge(leg: rides[i]),
                  ],
                ],
              ),
            ),
          TransitTimeline(
            itinerary: itinerary,
            originName:
                routeState.origin?.name ??
                itinerary.originStop?.name ??
                'Your location',
            destinationName:
                routeState.destination?.name ??
                itinerary.destinationStop?.name ??
                'Destination',
            imperial: imperial,
            liveLegIndex: progress?.legIndex,
            liveFraction: progress?.fractionInLeg,
            onStopTap: (TransitStop stop) => _openDepartures(ref, stop),
          ),
          const Divider(height: AppSpacing.lg),
          _TotalRow(nav: nav),
        ],
      ),
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

/// The journey's remaining time and arrival clock.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context) {
    final bool arrived = nav.status == NavStatus.arrived;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Text(
            arrived ? 'Trip complete' : formatDuration(nav.remaining),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (!arrived)
            Text(
              'Arrives ${arrivalLabel(context, nav.remaining)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
