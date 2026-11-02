import '../../domain/entities/location_sample.dart';
import '../../domain/ports/location_service.dart';
import 'sample_data.dart';

/// Fixed-position [LocationService] for keyless runs and tests.
class FakeLocationService implements LocationService {
  const FakeLocationService();

  static const LocationSample _sample = LocationSample(
    position: SampleData.origin,
    bearing: 0,
    speedMetersPerSecond: 0,
    accuracyMeters: 5,
  );

  @override
  Future<LocationSample?> lastKnown() async => _sample;

  @override
  Stream<LocationSample> positionStream() =>
      Stream<LocationSample>.value(_sample);
}
