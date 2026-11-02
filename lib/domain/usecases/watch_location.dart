import '../entities/location_sample.dart';
import '../ports/location_service.dart';

/// Streams position samples from [LocationService].
class WatchLocation {
  const WatchLocation(this._locationService);

  final LocationService _locationService;

  Stream<LocationSample> call() => _locationService.positionStream();
}
