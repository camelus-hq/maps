import 'route.dart';
import 'travel_mode.dart';

/// The tracking-camera zoom used by turn-by-turn guidance.
///
/// The camera zooms **out** as the traveller speeds up, so more of the road
/// ahead is visible, and **holds the close-in zoom while a turn is coming up**
/// so the junction stays legible. Holding the zoom (instead of zooming further
/// out) is the map-side counterpart of the guidance banner emphasising itself
/// as the maneuver nears: the tightening map is the "a turn is coming" cue.
///
/// Walking and cycling have their own (narrower) zoom-out ranges — a pedestrian
/// never sees a motorway-wide view — and public transport ignores this entirely:
/// a transit ride frames its whole leg instead, so its zoom is fixed.
class NavigationCamera {
  const NavigationCamera._();

  /// The close-in zoom held at a standstill and whenever a turn is imminent.
  static const double baseZoom = 17;

  /// The flat, north-up zoom a public-transport journey tracks at.
  static const double transitZoom = 16;

  /// The zoom profile for [mode] (speed range and turn approach distance).
  static NavigationZoomProfile profileFor(TravelMode mode) => switch (mode) {
    TravelMode.drive => const NavigationZoomProfile(
      minZoom: 14,
      baseSpeed: 4,
      fullSpeed: 28,
      turnApproachMeters: 250,
    ),
    TravelMode.cycle => const NavigationZoomProfile(
      minZoom: 15.5,
      baseSpeed: 1.5,
      fullSpeed: 7,
      turnApproachMeters: 130,
    ),
    TravelMode.walk => const NavigationZoomProfile(
      minZoom: 16.5,
      baseSpeed: 0.5,
      fullSpeed: 2.5,
      turnApproachMeters: 50,
    ),
    TravelMode.transit => const NavigationZoomProfile(
      minZoom: transitZoom,
      baseSpeed: 0,
      fullSpeed: 1,
      turnApproachMeters: 0,
      fixed: true,
    ),
  };

  /// The zoom for [mode] travelling at [speedMetersPerSecond] with
  /// [nextManeuver] [distanceToNextManeuver] metres ahead.
  ///
  /// A `null`, non-finite or negative speed is treated as "stationary" (the
  /// close-in [baseZoom]); transit always returns [transitZoom].
  static double zoom({
    required TravelMode mode,
    required double? speedMetersPerSecond,
    required Maneuver? nextManeuver,
    required double distanceToNextManeuver,
  }) {
    final NavigationZoomProfile profile = profileFor(mode);
    if (profile.fixed) {
      return transitZoom;
    }
    if (_turnIsNear(
      nextManeuver,
      distanceToNextManeuver,
      profile.turnApproachMeters,
    )) {
      return baseZoom;
    }
    return _speedZoom(profile, speedMetersPerSecond);
  }

  /// Whether [maneuver] is a real turn that is close enough to hold the zoom.
  static bool _turnIsNear(
    Maneuver? maneuver,
    double distanceMeters,
    double approachMeters,
  ) {
    if (maneuver == null || approachMeters <= 0) {
      return false;
    }
    if (!_isTurn(maneuver.type)) {
      return false;
    }
    return distanceMeters >= 0 && distanceMeters <= approachMeters;
  }

  /// A turn to prepare for — not setting off, not carrying straight on and not
  /// the arrival itself.
  static bool _isTurn(ManeuverType type) => switch (type) {
    ManeuverType.depart ||
    ManeuverType.straight ||
    ManeuverType.arrive ||
    ManeuverType.unknown => false,
    _ => true,
  };

  static double _speedZoom(NavigationZoomProfile profile, double? speed) {
    final double resolved = speed == null || !speed.isFinite || speed < 0
        ? profile.baseSpeed
        : speed;
    final double span = profile.fullSpeed - profile.baseSpeed;
    final double t = span <= 0
        ? 1
        : ((resolved - profile.baseSpeed) / span).clamp(0.0, 1.0);
    return baseZoom - t * (baseZoom - profile.minZoom);
  }
}

/// How one travel mode's guidance zoom responds to speed and turns.
class NavigationZoomProfile {
  const NavigationZoomProfile({
    required this.minZoom,
    required this.baseSpeed,
    required this.fullSpeed,
    required this.turnApproachMeters,
    this.fixed = false,
  });

  /// The furthest the camera zooms out, reached at [fullSpeed].
  final double minZoom;

  /// At or below this speed the camera holds [NavigationCamera.baseZoom].
  final double baseSpeed;

  /// At or above this speed the camera is fully zoomed out ([minZoom]).
  final double fullSpeed;

  /// A turn within this distance holds the close-in zoom.
  final double turnApproachMeters;

  /// Transit keeps one flat pose and ignores both speed and turns.
  final bool fixed;
}
