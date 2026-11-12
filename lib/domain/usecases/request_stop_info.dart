import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/transit.dart';
import '../ports/transit_routing_service.dart';

/// Reads one stop's static information (id, name, and the lines serving it)
/// through [TransitRoutingService], validating the request and normalising
/// failures into a [Result].
class RequestStopInfo {
  const RequestStopInfo(this._service);

  final TransitRoutingService _service;

  Future<Result<TransitStopInfo>> call(TransitStopQuery query) async {
    if (!query.isResolved) {
      return const Err(
        ValidationException('A stop id or a coordinate is required'),
      );
    }
    try {
      final TransitStopInfo info = await _service.stopInfo(query);
      return Ok(info);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Loading the stop failed', cause: error));
    }
  }
}
