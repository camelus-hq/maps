import '../entities/location_sample.dart';

/// Provides device position. Implemented over Android GNSS in `data/`.
abstract interface class LocationService {
  /// The most recent known fix, if any.
  Future<LocationSample?> lastKnown();

  /// A stream of position updates.
  Stream<LocationSample> positionStream();
}
