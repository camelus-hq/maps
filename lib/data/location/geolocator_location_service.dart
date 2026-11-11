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
/// The optional [positionEvents] / [compassEvents] / [permissionCheck] /
/// [serviceStatusEvents] seams exist so tests can drive the stream lifecycle
/// without platform channels.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    Stream<Position> Function()? positionEvents,
    Stream<CompassEvent>? compassEvents,
    Future<bool> Function()? permissionCheck,
    Stream<ServiceStatus> Function()? serviceStatusEvents,
  }) : _positionEvents = positionEvents ?? _defaultPositionEvents,
       _compassEvents = compassEvents ?? FlutterCompass.events,
       _permissionCheck = permissionCheck ?? _defaultPermissionCheck,
       _serviceStatusEvents =
           serviceStatusEvents ?? Geolocator.getServiceStatusStream;

  // A plain `LocationSettings` sends no `timeInterval`, so the Android
  // FusedLocationProvider falls back to its 5000 ms default — the position (and
  // therefore the distance, speed and elapsed readouts) only refreshed every
  // five seconds. `AndroidSettings` sets an explicit ~1 Hz interval, and
  // `distanceFilter: 0` keeps those updates coming when stopped (and at walking
  // pace) instead of waiting for 5 m of movement. On iOS `intervalDuration` is
  // ignored and CoreLocation delivers continuously.
  static final AndroidSettings _settings = AndroidSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    intervalDuration: const Duration(seconds: 1),
  );

  final Stream<Position> Function() _positionEvents;
  final Stream<CompassEvent>? _compassEvents;
  final Future<bool> Function() _permissionCheck;
  final Stream<ServiceStatus> Function() _serviceStatusEvents;

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

  Future<bool>? _permissionInFlight;

  /// Coalesces concurrent availability/position/`lastKnown` checks onto one
  /// permission request: geolocator throws `PermissionRequestInProgressException`
  /// if asked to request while another request is pending, and a lost race here
  /// would silently disable the availability signal.
  Future<bool> _ensurePermission() {
    final Future<bool>? inFlight = _permissionInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<bool> future = _permissionCheck();
    _permissionInFlight = future;
    unawaited(
      future.then<void>((bool _) {}, onError: (Object _) {}).whenComplete(() {
        if (identical(_permissionInFlight, future)) {
          _permissionInFlight = null;
        }
      }),
    );
    return future;
  }

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

  @override
  Stream<bool> availabilityStream() {
    final StreamController<bool> controller =
        StreamController<bool>.broadcast();
    StreamSubscription<ServiceStatus>? statusSub;
    bool cancelled = false;
    // Optimistic until the OS reports otherwise; the first status event (or the
    // permission check below) resolves it.
    bool serviceEnabled = true;

    // Availability = location services enabled AND permission granted. The
    // permission part reuses the same check the position stream uses, so the
    // two never disagree about whether the device can be located.
    Future<void> evaluate(bool? enabledNow) async {
      if (enabledNow != null) {
        serviceEnabled = enabledNow;
      }
      final bool available = serviceEnabled && await _ensurePermission();
      if (!cancelled && !controller.isClosed) {
        controller.add(available);
      }
    }

    Future<void> start() async {
      try {
        await evaluate(null);
        if (cancelled) {
          return;
        }
        // Re-evaluate whenever the user toggles location services in the OS.
        statusSub = _serviceStatusEvents().listen(
          (ServiceStatus status) =>
              unawaited(evaluate(status == ServiceStatus.enabled)),
          onError: (Object _) {},
        );
      } catch (_) {
        // Degrade to a silent stream: unknown availability never greys out a
        // usable fix.
      }
    }

    controller.onListen = () => unawaited(start());
    controller.onCancel = () async {
      cancelled = true;
      await statusSub?.cancel();
      statusSub = null;
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
