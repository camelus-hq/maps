import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/opening_hours.dart';

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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.schedule, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Text('Opening hours', style: theme.textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = highlighted ? scheme.primary : scheme.onSurface;
    final FontWeight weight = highlighted ? FontWeight.w600 : FontWeight.w400;
    return Padding(
      padding: const EdgeInsets.only(
        left: 36,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              day,
              style: TextStyle(
                fontSize: 13,
                color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: weight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hours,
              style: TextStyle(fontSize: 13, color: color, fontWeight: weight),
            ),
          ),
        ],
      ),
    );
  }
}
