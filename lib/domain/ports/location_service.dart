import '../entities/location_sample.dart';

/// Provides device position. Implemented over Android GNSS in `data/`.
abstract interface class LocationService {
  /// The most recent known fix, if any.
  Future<LocationSample?> lastKnown();

  /// A stream of position updates.
  Stream<LocationSample> positionStream();

  /// Whether the device can currently be located: location services are enabled
  /// and permission has been granted.
  ///
  /// Emits the current value when listened to, then again whenever the OS
  /// location service is toggled. Geolocator exposes **no** satellite-fix
  /// ("GPS lock") signal, so this honest "can we locate at all" state is the
  /// strongest availability signal available — we never infer signal loss from
  /// missing updates (a stationary device emits none).
  Stream<bool> availabilityStream();
}
