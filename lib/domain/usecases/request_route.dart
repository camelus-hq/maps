import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/lat_lon.dart';
import '../entities/route.dart';
import '../entities/travel_mode.dart';
import '../ports/routing_service.dart';

/// Runs a routing request through [RoutingService], validating inputs.
class RequestRoute {
  const RequestRoute(this._routingService);

  final RoutingService _routingService;

  Future<Result<List<Route>>> call({
    required List<LatLon> waypoints,
    required TravelMode mode,
  }) async {
    if (waypoints.length < 2) {
      return const Err(
        ValidationException('A route needs at least two waypoints'),
      );
    }
    try {
      final List<Route> routes = await _routingService.route(
        waypoints: waypoints,
        mode: mode,
      );
      if (routes.isEmpty) {
        return const Err(NotFoundException('No route found'));
      }
      return Ok(routes);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Routing failed', cause: error));
    }
  }
}
