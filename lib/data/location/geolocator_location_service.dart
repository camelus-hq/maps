import 'dart:async';

import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/location_sample.dart';
import '../../domain/ports/location_service.dart';

/// Real [LocationService] backed by the device GNSS (geolocator), with a
/// best-effort compass heading for when the device is (near) stationary.
///
/// Never throws to callers: missing permission, disabled location services or
/// platform errors degrade to "no fix" (null / empty stream).
///
/// The optional [positionEvents] / [compassEvents] / [permissionCheck] seams
/// exist so tests can drive the stream lifecycle without platform channels.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    Stream<Position> Function()? positionEvents,
    Stream<CompassEvent>? compassEvents,
    Future<bool> Function()? permissionCheck,
  }) : _positionEvents = positionEvents ?? _defaultPositionEvents,
       _compassEvents = compassEvents ?? FlutterCompass.events,
       _permissionCheck = permissionCheck ?? _defaultPermissionCheck;

  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 5,
  );

  final Stream<Position> Function() _positionEvents;
  final Stream<CompassEvent>? _compassEvents;
  final Future<bool> Function() _permissionCheck;

  static Stream<Position> _defaultPositionEvents() =>
      Geolocator.getPositionStream(locationSettings: _settings);

  static Future<bool> _defaultPermissionCheck() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> _ensurePermission() => _permissionCheck();

  @override
  Future<LocationSample?> lastKnown() async {
    try {
      if (!await _ensurePermission()) {
        return null;
      }
      // Prefer a fresh fix (so a moved device / emulator `geo fix` is
      // reflected promptly); fall back to the cached one.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: _settings,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      return position == null ? null : _toSample(position, null);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocationSample> positionStream() {
    final StreamController<LocationSample> controller =
        StreamController<LocationSample>.broadcast();
    StreamSubscription<Position>? positionSub;
    StreamSubscription<CompassEvent>? compassSub;
    double? compassHeading;
    bool cancelled = false;

    // Subscribing is asynchronous (permission may be requested); the caller can
    // cancel before it completes. `cancelled` makes sure we never leave the
    // geolocator/compass subscriptions running in that case (a leak that
    // otherwise grows with every follow/navigation toggle).
    Future<void> start() async {
      try {
        if (!await _ensurePermission() || cancelled) {
          return;
        }
        compassSub = _compassEvents?.listen((CompassEvent event) {
          compassHeading = event.heading;
        });
        positionSub = _positionEvents().listen((Position position) {
          final LocationSample? sample = _toSample(position, compassHeading);
          if (sample != null && !controller.isClosed) {
            controller.add(sample);
          }
        }, onError: (Object _) {});
      } catch (_) {
        // Degrade to no fix.
      }
    }

    controller.onListen = () => unawaited(start());
    controller.onCancel = () async {
      cancelled = true;
      await positionSub?.cancel();
      positionSub = null;
      await compassSub?.cancel();
      compassSub = null;
    };
    return controller.stream;
  }

  LocationSample? _toSample(Position position, double? compassHeading) {
    final LatLon? point = LatLon.tryParse(
      position.latitude,
      position.longitude,
    );
    if (point == null) {
      return null;
    }
    final double heading = position.heading;
    final bool moving = position.speed.isFinite && position.speed > 0.5;
    final double? bearing = moving && heading.isFinite
        ? heading
        : (compassHeading?.isFinite ?? false ? compassHeading : null);
    return LocationSample(
      position: point,
      bearing: bearing,
      speedMetersPerSecond: position.speed.isFinite ? position.speed : null,
      accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
    );
  }
}
