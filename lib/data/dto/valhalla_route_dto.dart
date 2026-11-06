import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/route.dart';
import '../valhalla/polyline_codec.dart';

/// Lenient mapper from a Valhalla `/route` response to domain [Route]s.
///
/// External JSON is hostile: every field is type-checked, unknown/bad values
/// are dropped, and a missing shape or summary degrades gracefully.
abstract final class ValhallaRouteDto {
  /// Maps the primary `trip` plus any `alternates` to routes (primary first).
  static List<Route> routesFromResponse(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return const <Route>[];
    }
    final List<Route> routes = <Route>[];
    final Route? primary = _routeFromTrip(raw['trip']);
    if (primary != null) {
      routes.add(primary);
    }
    final Object? alternates = raw['alternates'];
    if (alternates is List<Object?>) {
      for (final Object? alternate in alternates) {
        if (alternate is! Map<String, Object?>) {
          continue;
        }
        final Route? route = _routeFromTrip(alternate['trip']);
        if (route != null) {
          routes.add(route);
        }
      }
    }
    return routes;
  }

  static Route? _routeFromTrip(Object? rawTrip) {
    if (rawTrip is! Map<String, Object?>) {
      return null;
    }
    final List<Leg> legs = <Leg>[];
    final List<LatLon> geometry = <LatLon>[];
    final Object? rawLegs = rawTrip['legs'];
    if (rawLegs is List<Object?>) {
      for (final Object? rawLeg in rawLegs) {
        if (rawLeg is! Map<String, Object?>) {
          continue;
        }
        geometry.addAll(_legGeometry(rawLeg));
        legs.add(_leg(rawLeg));
      }
    }
    final Map<String, Object?> summary = _summary(rawTrip);
    return Route(
      legs: legs,
      distanceMeters: (_lengthKm(summary) ?? _sumLegLength(legs)) * 1000,
      duration: Duration(
        seconds: (_timeSeconds(summary) ?? _sumLegSeconds(legs)).round(),
      ),
      geometry: geometry,
    );
  }

  static List<LatLon> _legGeometry(Map<String, Object?> rawLeg) {
    final Object? shape = rawLeg['shape'];
    if (shape is String && shape.isNotEmpty) {
      return decodePolyline(shape);
    }
    return const <LatLon>[];
  }

  static Leg _leg(Map<String, Object?> rawLeg) {
    final List<Maneuver> maneuvers = <Maneuver>[];
    final Object? rawManeuvers = rawLeg['maneuvers'];
    if (rawManeuvers is List<Object?>) {
      for (final Object? rawManeuver in rawManeuvers) {
        if (rawManeuver is! Map<String, Object?>) {
          continue;
        }
        final Object? instruction = rawManeuver['instruction'];
        final double? lengthKm = _asDouble(rawManeuver['length']);
        maneuvers.add(
          Maneuver(
            instruction: instruction is String ? instruction : '',
            type: maneuverTypeFrom(rawManeuver['type']),
            distanceMeters: (lengthKm ?? 0) * 1000,
            streetName: _streetName(rawManeuver),
            lanes: _lanes(rawManeuver),
          ),
        );
      }
    }
    final Map<String, Object?> summary = _summary(rawLeg);
    return Leg(
      maneuvers: maneuvers,
      distanceMeters: (_lengthKm(summary) ?? 0) * 1000,
      duration: Duration(seconds: (_timeSeconds(summary) ?? 0).round()),
    );
  }

  /// Bounds: a lane sign never realistically has more than these, so hostile
  /// payloads cannot allocate unbounded lists.
  static const int _maxLanes = 12;
  static const int _maxIndicationsPerLane = 4;

  /// The first of Valhalla's `street_names` (the street the maneuver acts on).
  static String? _streetName(Map<String, Object?> maneuver) {
    final Object? names = maneuver['street_names'];
    if (names is! List<Object?>) {
      return null;
    }
    for (final Object? name in names.take(3)) {
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }
    return null;
  }

  /// Parses the lane guidance attached to the maneuver's intersections (the
  /// last intersection that carries lanes wins).
  static List<LaneGuidance> _lanes(Map<String, Object?> maneuver) {
    final Object? intersections = maneuver['intersections'];
    if (intersections is! List<Object?>) {
      return const <LaneGuidance>[];
    }
    for (final Object? intersection in intersections.reversed) {
      if (intersection is! Map<String, Object?>) {
        continue;
      }
      final Object? rawLanes = intersection['lanes'];
      if (rawLanes is! List<Object?>) {
        continue;
      }
      final List<LaneGuidance> lanes = <LaneGuidance>[];
      for (final Object? rawLane in rawLanes.take(_maxLanes)) {
        if (rawLane is! Map<String, Object?>) {
          continue;
        }
        final List<LaneIndication> indications = <LaneIndication>[];
        final Object? rawIndications = rawLane['indications'];
        if (rawIndications is List<Object?>) {
          for (final Object? indication in rawIndications.take(
            _maxIndicationsPerLane,
          )) {
            indications.add(LaneIndication.parse(indication));
          }
        }
        lanes.add(
          LaneGuidance(
            // Valhalla marks the lanes that continue the route as `valid`
            // (older responses use `active`).
            active: rawLane['valid'] == true || rawLane['active'] == true,
            indications: indications,
          ),
        );
      }
      if (lanes.isNotEmpty) {
        return lanes;
      }
    }
    return const <LaneGuidance>[];
  }

  static Map<String, Object?> _summary(Map<String, Object?> node) {
    final Object? summary = node['summary'];
    return summary is Map<String, Object?>
        ? summary
        : const <String, Object?>{};
  }

  static double? _lengthKm(Map<String, Object?> summary) =>
      _asDouble(summary['length']);

  static double? _timeSeconds(Map<String, Object?> summary) =>
      _asDouble(summary['time']);

  static double _sumLegLength(List<Leg> legs) =>
      legs.fold<double>(0, (double sum, Leg leg) => sum + leg.distanceMeters) /
      1000;

  static double _sumLegSeconds(List<Leg> legs) => legs.fold<double>(
    0,
    (double sum, Leg leg) => sum + leg.duration.inSeconds,
  );

  /// Maps Valhalla maneuver `type` codes to our [ManeuverType].
  static ManeuverType maneuverTypeFrom(Object? raw) {
    final int? code = switch (raw) {
      final int value => value,
      final double value => value.toInt(),
      _ => null,
    };
    return switch (code) {
      1 || 2 || 3 => ManeuverType.depart,
      4 || 5 || 6 => ManeuverType.arrive,
      8 || 21 => ManeuverType.straight,
      9 || 10 || 11 || 12 || 17 || 19 || 22 || 36 => ManeuverType.turnRight,
      13 || 14 || 15 || 16 || 18 || 20 || 23 || 37 => ManeuverType.turnLeft,
      24 => ManeuverType.merge,
      25 || 26 => ManeuverType.roundabout,
      _ => ManeuverType.unknown,
    };
  }

  static double? _asDouble(Object? value) => switch (value) {
    final double value => value,
    final int value => value.toDouble(),
    _ => null,
  };
}
