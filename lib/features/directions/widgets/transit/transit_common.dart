import 'package:flutter/material.dart';

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
