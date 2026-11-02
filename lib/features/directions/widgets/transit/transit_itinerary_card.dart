import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../domain/entities/transit.dart';
import 'transit_common.dart';
import 'transit_line_badge.dart';

/// A journey row in the list: status, time range, line badges and agency. A tap
/// opens the detail.
class TransitItineraryCard extends StatelessWidget {
  const TransitItineraryCard({
    super.key,
    required this.itinerary,
    required this.selected,
    required this.onTap,
  });

  final TransitItinerary itinerary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TransitLeg> rides = itinerary.rides;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _status(context, itinerary),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${transitClock(context, itinerary.startTime.toLocal())} – '
                      '${transitClock(context, itinerary.endTime.toLocal())}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    formatDuration(itinerary.duration),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _lineSummary(context, itinerary, rides),
              ),
              if (itinerary.agencies.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  itinerary.agencies.join(' · '),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context, TransitItinerary itinerary) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime start = itinerary.startTime.toLocal();
    final DateTime now = DateTime.now();
    final String label;
    if (itinerary.isCancelled) {
      label = 'Cancelled';
    } else if (!start.isAfter(now)) {
      label = 'Departing';
    } else {
      final int minutes = start.difference(now).inMinutes;
      label = minutes <= 60
          ? 'in $minutes min'
          : 'Departs ${transitClock(context, start)}';
    }
    final Color color = itinerary.isCancelled ? scheme.error : scheme.primary;
    final Duration? delay = itinerary.departureDelay;
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
        if (itinerary.hasRealtime && !itinerary.isCancelled) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.circle, size: 8, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            'Live',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.primary),
          ),
          if (delay != null && delay.inMinutes.abs() >= 1) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              transitDelayLabel(delay),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ],
    );
  }

  /// The compact line badges (or "Walk" when the journey is on foot only).
  List<Widget> _lineSummary(
    BuildContext context,
    TransitItinerary itinerary,
    List<TransitLeg> rides,
  ) {
    if (rides.isEmpty) {
      return <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.directions_walk, size: 18),
            const SizedBox(width: 4),
            Text(formatDuration(itinerary.duration)),
          ],
        ),
      ];
    }
    return <Widget>[
      for (int i = 0; i < rides.length; i++) ...<Widget>[
        if (i > 0)
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
        TransitLineBadge(leg: rides[i]),
      ],
    ];
  }
}
