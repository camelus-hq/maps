import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/transit.dart';
import '../ports/transit_routing_service.dart';

/// Runs a public-transport plan through [TransitRoutingService], validating
/// inputs and normalising failures into a [Result].
class RequestTransitRoute {
  const RequestTransitRoute(this._service);

  final TransitRoutingService _service;

  Future<Result<List<TransitItinerary>>> call(TransitQuery query) async {
    if (query.waypoints.length < 2) {
      return const Err(
        ValidationException('A journey needs at least two waypoints'),
      );
    }
    try {
      final List<TransitItinerary> itineraries = await _service.plan(query);
      if (itineraries.isEmpty) {
        return const Err(NotFoundException('No journeys found'));
      }
      return Ok(_rank(itineraries, query));
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Transit planning failed', cause: error));
    }
  }

  /// Applies the traveller's "Fewer transfers" / "Less walking" preferences as a
  /// client-side ranking, so the preference works with any provider that does
  /// not support it server-side. Without a preference the provider's own order
  /// (best first) is preserved.
  List<TransitItinerary> _rank(
    List<TransitItinerary> itineraries,
    TransitQuery query,
  ) {
    if (!query.fewerTransfers && !query.lessWalking) {
      return itineraries;
    }
    final List<TransitItinerary> ranked = List<TransitItinerary>.of(
      itineraries,
    );
    ranked.sort((TransitItinerary a, TransitItinerary b) {
      if (query.fewerTransfers) {
        final int byTransfers = a.transfers.compareTo(b.transfers);
        if (byTransfers != 0) {
          return byTransfers;
        }
      }
      if (query.lessWalking) {
        final int byWalking = a.walkingMeters.compareTo(b.walkingMeters);
        if (byWalking != 0) {
          return byWalking;
        }
      }
      return a.duration.compareTo(b.duration);
    });
    return List<TransitItinerary>.unmodifiable(ranked);
  }
}
