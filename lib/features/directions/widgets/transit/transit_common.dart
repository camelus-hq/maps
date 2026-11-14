import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/transit.dart';

/// The transit mode's glyph (our own icon choice, no external assets).
IconData transitModeIcon(TransitMode mode) => switch (mode) {
  TransitMode.bus ||
  TransitMode.regionalBus ||
  TransitMode.coach ||
  TransitMode.trolleybus => Icons.directions_bus,
  TransitMode.tram => Icons.tram,
  TransitMode.subway || TransitMode.metro => Icons.subway,
  TransitMode.rail ||
  TransitMode.regionalRail ||
  TransitMode.highSpeedRail ||
  TransitMode.longDistanceRail ||
  TransitMode.nightRail ||
  TransitMode.suburbanRail => Icons.train,
  TransitMode.ferry => Icons.directions_boat,
  TransitMode.cableCar ||
  TransitMode.aerialLift ||
  TransitMode.funicular => Icons.directions_transit,
  TransitMode.monorail => Icons.tram,
  TransitMode.walk => Icons.directions_walk,
  TransitMode.bike => Icons.directions_bike,
  TransitMode.car => Icons.directions_car,
  TransitMode.other => Icons.directions_transit,
};

/// A localised clock label, e.g. "11:28 AM" (respects the 12/24-hour setting).
String transitClock(BuildContext context, DateTime time) {
  final TimeOfDay tod = TimeOfDay.fromDateTime(time);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    tod,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// "2 min late" / "1 min early".
String transitDelayLabel(Duration delay) {
  final int minutes = delay.inMinutes.abs();
  return delay.isNegative ? '$minutes min early' : '$minutes min late';
}

/// A short punctuality label for a ride leg: "Cancelled", "3 min late",
/// "1 min early", "On time" (a realtime feed) or "Scheduled" (timetable only).
String transitRideStatus(TransitLeg leg) {
  if (leg.cancelled) {
    return 'Cancelled';
  }
  final Duration? delay = leg.departureDelay;
  if (delay != null && delay.inMinutes.abs() >= 1) {
    return transitDelayLabel(delay);
  }
  return leg.realTime ? 'On time' : 'Scheduled';
}

/// The same punctuality label for a departure-board row.
String transitDepartureStatus(TransitStopDeparture departure) {
  if (departure.cancelled) {
    return 'Cancelled';
  }
  final Duration? delay = departure.delay;
  if (delay != null && delay.inMinutes.abs() >= 1) {
    return transitDelayLabel(delay);
  }
  return departure.realTime ? 'On time' : 'Scheduled';
}

/// A short relative label for a departure time: "now" (within a minute),
/// "in 5 min" (up to an hour ahead) or "3 min ago" (up to ten minutes past).
/// `null` when the time is too far away (or too long ago) for a relative label.
String? relativeTimeLabel(DateTime target, {DateTime? now}) {
  final Duration diff = target.difference(now ?? DateTime.now());
  final int seconds = diff.inSeconds;
  if (seconds.abs() < 60) {
    return 'now';
  }
  if (seconds < 0) {
    final int ago = (-seconds / 60).ceil();
    return ago <= 10 ? '$ago min ago' : null;
  }
  final int ahead = seconds ~/ 60;
  return ahead <= 60 ? 'in $ahead min' : null;
}

/// A small "Live" pill marking realtime (rather than timetable-only) data.
///
/// Shown wherever a live feed exists, so the traveller can tell a realtime
/// status from a scheduled one.
class TransitLiveBadge extends StatelessWidget {
  const TransitLiveBadge({super.key, this.onDark = false});

  /// Draw it for a dark background (the guidance card) instead of a surface.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color color = onDark
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            'Live',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A light, neutral "Platform N" chip — the reference's platform pill, used on
/// the dark guidance card.
class TransitPlatformChip extends StatelessWidget {
  const TransitPlatformChip({super.key, required this.track});

  final String track;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EAEC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Platform $track',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF3C4043),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
