import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../domain/entities/transit.dart';
import '../../../design/play.dart';
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
    final PlayColors colors = PlayColors.of(context);
    final List<TransitLeg> rides = itinerary.rides;
    return PlaySurface(
      radius: AppSpacing.sheetRadius,
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: PlayShadow.none,
      borderWidth: selected ? 2 : 1,
      borderColor: selected ? colors.primary : colors.line,
      backgroundColor: selected ? colors.surfaceSunken : colors.surface,
      onTap: onTap,
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
                  style: PlayType.subtitle.copyWith(color: colors.ink),
                ),
              ),
              Text(
                formatDuration(itinerary.duration),
                style: PlayType.subtitle.copyWith(color: colors.ink),
              ),
              Icon(PlayIcons.next, color: colors.inkFaint),
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
              style: PlayType.caption.copyWith(color: colors.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  Widget _status(BuildContext context, TransitItinerary itinerary) {
    final PlayColors colors = PlayColors.of(context);
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
    final Color color = itinerary.isCancelled ? colors.coral : colors.primary;
    final Duration? delay = itinerary.departureDelay;
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PlayType.bodyStrong.copyWith(color: color),
          ),
        ),
        if (itinerary.hasRealtime && !itinerary.isCancelled) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Icon(PlayIcons.dot, size: 8, color: colors.primary),
          const SizedBox(width: 4),
          Text('Live', style: PlayType.caption.copyWith(color: colors.primary)),
          if (delay != null && delay.inMinutes.abs() >= 1) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              transitDelayLabel(delay),
              style: PlayType.caption.copyWith(color: colors.coral),
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
            Icon(transitModeIcon(TransitMode.walk), size: 18),
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
            PlayIcons.next,
            size: 18,
            color: PlayColors.of(context).inkFaint,
          ),
        TransitLineBadge(leg: rides[i]),
      ],
    ];
  }
}
