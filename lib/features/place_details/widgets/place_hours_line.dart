import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/opening_hours.dart';

/// The place sheet's opening-hours line.
///
/// Shows a green/orange/red status with the next change ("Open now · Closes
/// 20:00", "Closing soon · Closes 20:00", "Opening soon · Opens 12:00", "Closed
/// now"), the raw OSM tag when we cannot read it, or "Hours not listed".
class PlaceHoursLine extends StatelessWidget {
  const PlaceHoursLine({super.key, required this.hours, this.now});

  /// The raw OSM `opening_hours` value, or `null`.
  final String? hours;

  /// The reference time; injectable so tests can pin open/soon/closed states.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? base = theme.textTheme.bodyMedium;
    final String? value = hours?.trim();
    final OpeningHoursStatus? status = evaluateOpeningHours(
      hours,
      now ?? DateTime.now(),
    );

    if (status != null) {
      final (Color color, String label) = switch (status.state) {
        OpeningState.open => (AppColors.statusOpen, 'Open now'),
        OpeningState.closingSoon => (AppColors.statusSoon, 'Closing soon'),
        OpeningState.openingSoon => (AppColors.statusSoon, 'Opening soon'),
        OpeningState.closed => (AppColors.statusClosed, 'Closed now'),
      };
      final String? change = status.nextChangeMinutes == null
          ? null
          : '${status.isOpen ? 'Closes' : 'Opens'} '
                '${_clock(status.nextChangeMinutes!)}';
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: base?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
            if (change != null) ...<Widget>[
              Text(
                ' · ',
                style: base?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Flexible(
                child: Text(
                  change,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (value != null && value.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                value,
                style: base?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        'Hours not listed',
        style: base?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  static String _clock(int minutes) {
    final int h = (minutes ~/ 60).clamp(0, 23);
    final int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
