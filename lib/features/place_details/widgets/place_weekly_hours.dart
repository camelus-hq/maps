import 'package:flutter/widgets.dart';

import '../../../core/utils/opening_hours.dart';
import '../../design/play.dart';

/// The Overview tab's general opening hours: the whole week, with today's row
/// highlighted.
///
/// Renders nothing when the tag is absent or unreadable — the summary line
/// above already shows the live status or the raw tag, so repeating it here
/// would only add noise.
class PlaceWeeklyHours extends StatelessWidget {
  const PlaceWeeklyHours({super.key, required this.hours, this.now});

  /// The raw OSM `opening_hours` value, or `null`.
  final String? hours;

  /// The reference day (its month picks the season and its weekday is
  /// highlighted); injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime at = now ?? DateTime.now();
    final List<OpeningDay>? days = weeklyOpeningHours(hours, at);
    if (days == null) {
      return const SizedBox.shrink();
    }
    final PlayColors colors = PlayColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(PlayIcons.clock, size: 20, color: colors.inkMuted),
            const SizedBox(width: PlaySpace.md),
            Text(
              'Opening hours',
              style: PlayType.bodyStrong.copyWith(color: colors.ink),
            ),
          ],
        ),
        const SizedBox(height: PlaySpace.xs),
        if (days.every((OpeningDay day) => day.isAllDay))
          _row(context, 'Every day', 'Open 24 hours', highlighted: true)
        else
          for (final OpeningDay day in days)
            _row(
              context,
              day.dayName,
              day.hoursLabel,
              highlighted: day.weekday == at.weekday,
            ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String day,
    String hours, {
    required bool highlighted,
  }) {
    final PlayColors colors = PlayColors.of(context);
    final Color valueColor = highlighted ? colors.primary : colors.ink;
    final Color dayColor = highlighted ? colors.primary : colors.inkMuted;
    final FontWeight weight = highlighted ? FontWeight.w700 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.only(
        left: 36,
        top: PlaySpace.xs,
        bottom: PlaySpace.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              day,
              style: PlayType.caption.copyWith(
                color: dayColor,
                fontWeight: weight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hours,
              style: PlayType.caption.copyWith(
                color: valueColor,
                fontWeight: weight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
