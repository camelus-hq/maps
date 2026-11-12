import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/transit.dart';
import 'transit_common.dart';
import 'transit_line_chip.dart';

/// One departure: the line chip, where it is headed and when it leaves.
///
/// Shared by the floating "Departures" board (opened from a journey timeline or
/// a live trip) and the station sheet's Departures tab.
class TransitDepartureRow extends StatelessWidget {
  const TransitDepartureRow({super.key, required this.departure, this.onTap});

  final TransitStopDeparture departure;

  /// Invoked when the row is tapped (opens the train detail); when `null` the
  /// row is not tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String status = transitDepartureStatus(departure);
    final bool bad = departure.cancelled;
    final DateTime when = departure.displayDeparture.toLocal();
    final DateTime now = DateTime.now();
    final bool past = when.isBefore(now);
    final String? relative = relativeTimeLabel(when, now: now);
    final String? track = departure.displayTrack;
    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TransitLineChip(
            label: departure.lineLabel,
            color: departure.displayColor,
            textColor: departure.routeTextColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  departure.headsign ?? departure.routeLongName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: past ? scheme.outline : null),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        <String>[
                          status,
                          transitClock(context, when),
                          ?relative,
                          if (track != null) 'Platform $track',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: bad
                              ? scheme.error
                              : past
                              ? scheme.outline
                              : (departure.realTime
                                    ? scheme.primary
                                    : scheme.outline),
                        ),
                      ),
                    ),
                    if (departure.realTime && !bad && !past) ...<Widget>[
                      const SizedBox(width: 6),
                      const TransitLiveBadge(),
                    ],
                  ],
                ),
                if (departure.agencyName != null)
                  Text(
                    departure.agencyName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
              ],
            ),
          ),
          if (departure.wheelchairAccessible || departure.bikesAllowed)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (departure.wheelchairAccessible)
                    Icon(Icons.accessible, size: 16, color: scheme.outline),
                  if (departure.bikesAllowed)
                    Icon(Icons.pedal_bike, size: 16, color: scheme.outline),
                ],
              ),
            ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}
