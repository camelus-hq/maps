import '../entities/lat_lon.dart';
import '../entities/route.dart';
import '../entities/travel_mode.dart';

/// Computes routes. Implemented by the Valhalla adapter in `data/valhalla/`.
abstract interface class RoutingService {
  /// Routes through [waypoints] (origin first, destination last). Returns the
  /// primary route first and any alternatives after it.
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
  });
}
