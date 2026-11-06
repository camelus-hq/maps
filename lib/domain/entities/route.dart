import 'lat_lon.dart';

/// How a [Maneuver] is announced and iconified.
///
/// Kept granular on purpose: a slight/regular/sharp turn, a U-turn, a
/// "keep left/right", a ramp/exit and a merge each get their own glyph, so a
/// left maneuver is never drawn as a right/merge arrow and a "turn slightly
/// right" is not flattened into a plain right turn.
enum ManeuverType {
  depart,
  straight,
  slightLeft,
  turnLeft,
  sharpLeft,
  uTurnLeft,
  slightRight,
  turnRight,
  sharpRight,
  uTurnRight,
  keepLeft,
  keepRight,
  rampLeft,
  rampRight,
  exitLeft,
  exitRight,
  merge,
  mergeLeft,
  mergeRight,
  roundabout,
  roundaboutExit,
  arrive,
  unknown,
}

/// A lane indication on a sign/gantry (Valhalla lane `directions` bitmask or
/// the legacy `indications` strings).
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
  mergeLeft,
  mergeRight,
  forkLeft,
  forkRight,
  reverse,
  unknown;

  /// Valhalla `lane.directions` bitmask values (a lane lists every bit it is
  /// signed for, e.g. `10` is Left(8) + Through(2)).
  static const int bitNone = 1;
  static const int bitThrough = 2;
  static const int bitSharpLeft = 4;
  static const int bitLeft = 8;
  static const int bitSlightLeft = 16;
  static const int bitSlightRight = 32;
  static const int bitRight = 64;
  static const int bitSharpRight = 128;
  static const int bitReverse = 256;
  static const int bitMergeLeft = 512;
  static const int bitMergeRight = 1024;

  /// Expands a Valhalla lane bitmask into the indications it carries.
  ///
  /// Turning directions are listed before "through" so a lane signed for both
  /// (e.g. Left + Through) draws the arrow that matters for the maneuver.
  static List<LaneIndication> fromBitmask(int mask) {
    final List<LaneIndication> out = <LaneIndication>[];
    void add(int bit, LaneIndication value) {
      if (mask & bit != 0) {
        out.add(value);
      }
    }

    add(bitReverse, LaneIndication.reverse);
    add(bitSharpLeft, LaneIndication.sharpLeft);
    add(bitLeft, LaneIndication.left);
    add(bitSlightLeft, LaneIndication.slightLeft);
    add(bitMergeLeft, LaneIndication.mergeLeft);
    add(bitSharpRight, LaneIndication.sharpRight);
    add(bitRight, LaneIndication.right);
    add(bitSlightRight, LaneIndication.slightRight);
    add(bitMergeRight, LaneIndication.mergeRight);
    add(bitThrough, LaneIndication.straight);
    return out;
  }

  /// Parses a legacy Valhalla indication string, tolerating unknown values.
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
      'merge left' || 'merge_left' => LaneIndication.mergeLeft,
      'merge right' || 'merge_right' => LaneIndication.mergeRight,
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
    this.valid = false,
    this.indications = const <LaneIndication>[],
  });

  /// Whether this lane is the preferred lane for the maneuver (Valhalla
  /// `active` bitmask); highlighted in the UI.
  final bool active;

  /// Whether the lane can be used for the maneuver (Valhalla `valid` bitmask);
  /// shown normal, while lanes that do not lead through are dimmed.
  final bool valid;

  /// Directions the lane is signed for (Valhalla `directions` bitmask).
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
