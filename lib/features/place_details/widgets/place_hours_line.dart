import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/opening_hours.dart';
import '../../design/play.dart';

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
    final PlayColors colors = PlayColors.of(context);
    final TextStyle base = PlayType.body.copyWith(color: colors.ink);
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
      final int? changeMinutes = status.nextChangeMinutes;
      final String? change = changeMinutes == null
          ? null
          : '${status.isOpen ? 'Closes' : 'Opens'} ${_clock(changeMinutes)}';
      return Padding(
        padding: const EdgeInsets.only(top: PlaySpace.xs),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: PlaySpace.sm),
            Text(
              label,
              style: base.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            if (change != null) ...<Widget>[
              Text(' · ', style: base.copyWith(color: colors.inkMuted)),
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
        padding: const EdgeInsets.only(top: PlaySpace.xs),
        child: Row(
          children: <Widget>[
            Icon(PlayIcons.clock, size: 16, color: colors.inkMuted),
            const SizedBox(width: PlaySpace.xs),
            Expanded(
              child: Text(value, style: base.copyWith(color: colors.inkMuted)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: PlaySpace.xs),
      child: Text(
        'Hours not listed',
        style: base.copyWith(color: colors.inkMuted),
      ),
    );
  }

  static String _clock(int minutes) {
    final int h = (minutes ~/ 60).clamp(0, 23);
    final int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
