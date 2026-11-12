import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/transit.dart';
import '../ports/transit_routing_service.dart';

/// Reads the full shape of one trip through [TransitRoutingService] (used to
/// draw a line on the map for a tapped stop), validating the request and
/// normalising failures into a [Result].
class RequestTransitTrip {
  const RequestTransitTrip(this._service);

  final TransitRoutingService _service;

  Future<Result<TransitItinerary>> call(String tripId) async {
    if (tripId.trim().isEmpty) {
      return const Err(ValidationException('A trip id is required'));
    }
    try {
      final TransitItinerary itinerary = await _service.trip(tripId);
      return Ok(itinerary);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Loading the trip failed', cause: error));
    }
  }
}
