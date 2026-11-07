import 'package:flutter/material.dart';

import '../../../domain/entities/travel_mode.dart';

/// How urgent the next maneuver is (drives the banner emphasis).
enum NavUrgency {
  /// Far from the turn (or no maneuver).
  none,

  /// Getting close — the banner hints at the upcoming turn.
  soon,

  /// Just about to turn — the banner is emphasised ("turn now").
  now,
}

/// Per-travel-mode presentation for the guidance overlay.
///
/// Selecting a view by [TravelMode] (rather than hard-coding one navigation
/// screen) is what lets a mixed-mode journey re-skin the same live map when the
/// mode changes mid-route.
class NavStyle {
  const NavStyle({
    required this.banner,
    required this.bannerNow,
    required this.bannerAccent,
    required this.laneStrip,
    required this.soonMeters,
    required this.nowMeters,
    required this.showLanes,
    required this.showSpeed,
    required this.speedLimitKmh,
  });

  /// Banner background.
  final Color banner;

  /// Banner background once the turn is imminent (a brighter attention shade).
  final Color bannerNow;

  /// Text/icon colour on the banner.
  final Color bannerAccent;

  /// Lane-guidance strip background.
  final Color laneStrip;

  /// Distance under which the banner becomes "soon".
  final double soonMeters;

  /// Distance under which the banner becomes "now".
  final double nowMeters;

  final bool showLanes;

  /// Whether to show the current-speed chip.
  final bool showSpeed;

  /// The regulatory speed limit shown in the chip (km/h), when known.
  final int? speedLimitKmh;

  NavUrgency urgency(double distanceMeters) {
    if (distanceMeters <= nowMeters) {
      return NavUrgency.now;
    }
    if (distanceMeters <= soonMeters) {
      return NavUrgency.soon;
    }
    return NavUrgency.none;
  }

  /// The style for [mode]. Drive is the fully-featured reference layout; the
  /// others share the atoms with their own emphases.
  factory NavStyle.forMode(TravelMode mode) {
    switch (mode) {
      case TravelMode.drive:
        return const NavStyle(
          banner: Color(0xFF0B4740),
          bannerNow: Color(0xFF0E6B5E),
          bannerAccent: Colors.white,
          laneStrip: Color(0xFF083A34),
          soonMeters: 350,
          nowMeters: 80,
          showLanes: true,
          showSpeed: true,
          speedLimitKmh: null,
        );
      case TravelMode.cycle:
        // A bicycle is not bound to road lanes, so cycling guidance never shows
        // the lane strip (the car layout keeps it).
        return const NavStyle(
          banner: Color(0xFF116B5B),
          bannerNow: Color(0xFF0E8A6E),
          bannerAccent: Colors.white,
          laneStrip: Color(0xFF0C5245),
          soonMeters: 200,
          nowMeters: 50,
          showLanes: false,
          showSpeed: true,
          speedLimitKmh: null,
        );
      case TravelMode.walk:
        return const NavStyle(
          banner: Color(0xFF0F5F73),
          bannerNow: Color(0xFF13808C),
          bannerAccent: Colors.white,
          laneStrip: Color(0xFF0B4A59),
          soonMeters: 60,
          nowMeters: 18,
          showLanes: false,
          showSpeed: false,
          speedLimitKmh: null,
        );
      case TravelMode.transit:
        return const NavStyle(
          banner: Color(0xFF26306E),
          bannerNow: Color(0xFF33409A),
          bannerAccent: Colors.white,
          laneStrip: Color(0xFF1C2452),
          soonMeters: 120,
          nowMeters: 40,
          showLanes: false,
          showSpeed: false,
          speedLimitKmh: null,
        );
    }
  }
}

/// A short label for a mode (used by the mode switcher).
String travelModeLabel(TravelMode mode) => switch (mode) {
  TravelMode.drive => 'Drive',
  TravelMode.walk => 'Walk',
  TravelMode.cycle => 'Cycle',
  TravelMode.transit => 'Transit',
};

/// The mode glyph (our own Material symbols; no proprietary iconography).
IconData travelModeIcon(TravelMode mode) => switch (mode) {
  TravelMode.drive => Icons.directions_car,
  TravelMode.walk => Icons.directions_walk,
  TravelMode.cycle => Icons.directions_bike,
  TravelMode.transit => Icons.directions_transit,
};
