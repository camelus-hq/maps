import 'lat_lon.dart';

/// How a [Maneuver] is announced and iconified.
enum ManeuverType {
  depart,
  straight,
  turnLeft,
  turnRight,
  merge,
  roundabout,
  arrive,
  unknown,
}

/// A single turn-by-turn instruction.
class Maneuver {
  const Maneuver({
    required this.instruction,
    required this.type,
    this.distanceMeters = 0,
  });

  final String instruction;
  final ManeuverType type;
  final double distanceMeters;
}

/// A contiguous portion of a route between two waypoints.
class Leg {
  const Leg({
    required this.maneuvers,
    required this.distanceMeters,
    required this.duration,
  });

  final List<Maneuver> maneuvers;
  final double distanceMeters;
  final Duration duration;
}

/// A computed route from origin to destination.
class Route {
  const Route({
    required this.legs,
    required this.distanceMeters,
    required this.duration,
    required this.geometry,
  });

  final List<Leg> legs;
  final double distanceMeters;
  final Duration duration;

  /// Ordered polyline vertices.
  final List<LatLon> geometry;
}
