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

/// A lane indication on a sign/gantry (Valhalla `indications`).
enum LaneIndication {
  left,
  slightLeft,
  sharpLeft,
  straight,
  slightRight,
  sharpRight,
  right,
  uTurn,
  merge,
  forkLeft,
  forkRight,
  reverse,
  unknown;

  /// Parses a Valhalla indication string, tolerating unknown values.
  static LaneIndication parse(Object? raw) {
    if (raw is! String) {
      return LaneIndication.unknown;
    }
    return switch (raw.toLowerCase()) {
      'left' => LaneIndication.left,
      'slight left' || 'slight_left' => LaneIndication.slightLeft,
      'sharp left' || 'sharp_left' => LaneIndication.sharpLeft,
      'through' || 'straight' => LaneIndication.straight,
      'slight right' || 'slight_right' => LaneIndication.slightRight,
      'sharp right' || 'sharp_right' => LaneIndication.sharpRight,
      'right' => LaneIndication.right,
      'uturn' || 'u_turn' || 'u-turn' => LaneIndication.uTurn,
      'merge' => LaneIndication.merge,
      'fork left' || 'fork_left' => LaneIndication.forkLeft,
      'fork right' || 'fork_right' => LaneIndication.forkRight,
      'reverse' => LaneIndication.reverse,
      _ => LaneIndication.unknown,
    };
  }
}

/// One lane in a lane-guidance sign.
class LaneGuidance {
  const LaneGuidance({
    this.active = false,
    this.indications = const <LaneIndication>[],
  });

  /// Whether this lane leads to the maneuver (Valhalla `valid`/`active`);
  /// highlighted in the UI.
  final bool active;

  final List<LaneIndication> indications;

  /// The lane's primary indication for drawing.
  LaneIndication get primary =>
      indications.isEmpty ? LaneIndication.straight : indications.first;
}

/// A single turn-by-turn instruction.
class Maneuver {
  const Maneuver({
    required this.instruction,
    required this.type,
    this.distanceMeters = 0,
    this.streetName,
    this.lanes = const <LaneGuidance>[],
  });

  final String instruction;
  final ManeuverType type;
  final double distanceMeters;

  /// The street the instruction acts on (Valhalla `street_names`), when known.
  final String? streetName;

  /// Lane guidance for the maneuver (empty when the provider has none).
  final List<LaneGuidance> lanes;
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
