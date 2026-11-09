import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/transit.dart';
import '../ports/transit_routing_service.dart';

/// Reads the next departures from one stop through [TransitRoutingService],
/// validating the request and normalising failures into a [Result].
class RequestStopDepartures {
  const RequestStopDepartures(this._service);

  final TransitRoutingService _service;

  Future<Result<List<TransitStopDeparture>>> call(
    TransitDeparturesQuery query,
  ) async {
    if (query.stopId.trim().isEmpty) {
      return const Err(ValidationException('A stop id is required'));
    }
    try {
      final List<TransitStopDeparture> departures = await _service.departures(
        query,
      );
      return Ok(departures);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Loading departures failed', cause: error));
    }
  }
}
