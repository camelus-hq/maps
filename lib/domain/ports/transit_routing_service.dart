import '../entities/transit.dart';

/// Plans public-transport journeys.
///
/// Implemented in `data/` by the Transitous (MOTIS 2) adapter; swapping the
/// provider means one override in `lib/app/di.dart`, with no widget or notifier
/// changes. The domain talks in [TransitQuery]/[TransitItinerary] only, so the
/// provider's wire format never leaks inward.
abstract interface class TransitRoutingService {
  /// Returns the best journeys first. Implementations must never throw an
  /// untyped error: failures surface as [AppException]s from `core/errors`.
  Future<List<TransitItinerary>> plan(TransitQuery query);
}
