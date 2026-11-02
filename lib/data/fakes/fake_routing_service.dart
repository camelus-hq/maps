import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/ports/routing_service.dart';

/// Keyless [RoutingService] that lays a straight line between waypoints; the
/// Valhalla adapter lands in M4.
class FakeRoutingService implements RoutingService {
  const FakeRoutingService();

  static const int _samplesPerSegment = 8;

  @override
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
  }) async {
    final List<Leg> legs = <Leg>[];
    final List<LatLon> geometry = <LatLon>[];
    double totalDistance = 0;
    Duration totalDuration = Duration.zero;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final LatLon from = waypoints[i];
      final LatLon to = waypoints[i + 1];
      final double segmentMeters = from.distanceTo(to);

      for (int s = (i == 0 ? 0 : 1); s <= _samplesPerSegment; s++) {
        final double t = s / _samplesPerSegment;
        geometry.add(
          LatLon(
            from.latitude + (to.latitude - from.latitude) * t,
            from.longitude + (to.longitude - from.longitude) * t,
          ),
        );
      }

      final Duration segmentDuration = _durationFor(segmentMeters, mode);
      legs.add(
        Leg(
          maneuvers: <Maneuver>[
            Maneuver(
              instruction: 'Head toward waypoint ${i + 2}',
              type: ManeuverType.depart,
              distanceMeters: segmentMeters,
            ),
            Maneuver(
              instruction: 'Arrive at waypoint ${i + 2}',
              type: ManeuverType.arrive,
            ),
          ],
          distanceMeters: segmentMeters,
          duration: segmentDuration,
        ),
      );
      totalDistance += segmentMeters;
      totalDuration += segmentDuration;
    }

    return <Route>[
      Route(
        legs: legs,
        distanceMeters: totalDistance,
        duration: totalDuration,
        geometry: geometry,
      ),
    ];
  }

  Duration _durationFor(double meters, TravelMode mode) {
    final double metersPerSecond = switch (mode) {
      TravelMode.drive => 13.9, // ~50 km/h
      TravelMode.cycle => 4.2, // ~15 km/h
      TravelMode.walk => 1.4, // ~5 km/h
      TravelMode.transit => 7.0, // ~25 km/h average with stops
    };
    final int seconds = (meters / metersPerSecond)
        .round()
        .clamp(1, 86400)
        .toInt();
    return Duration(seconds: seconds);
  }
}
