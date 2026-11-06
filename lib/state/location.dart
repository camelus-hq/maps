import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/location_sample.dart';
import '../domain/ports/location_service.dart';
import 'ports.dart';

/// Live device-location presence for the map.
///
/// One subscription shared by every consumer (follow, guidance, the location
/// puck) so the GNSS stream is opened once, and one place that answers "can we
/// locate the device?" — which the follow button and the (greyed) last known
/// location puck reflect.
class LocationState {
  const LocationState({
    this.fix,
    this.fixAt,
    this.streaming = false,
    this.lost = false,
  });

  /// The most recent fix, kept even after the signal is lost so the map can
  /// still show where the user was.
  final LocationSample? fix;

  /// When [fix] was received.
  final DateTime? fixAt;

  /// True about a fix we can show: one has arrived (or was seeded) and location
  /// is currently available.
  final bool streaming;

  /// True when the device cannot be located — the OS location service is off,
  /// permission was denied, or the position stream errored. The last fix is
  /// retained so it can be shown greyed out.
  ///
  /// This is deliberately **not** derived from how long ago a fix arrived:
  /// geolocator exposes no satellite-fix signal, and a stationary device emits
  /// no updates, so an idle timer would wrongly report "lost".
  final bool lost;

  bool get hasFix => fix != null;

  LocationState copyWith({
    LocationSample? fix,
    DateTime? fixAt,
    bool? streaming,
    bool? lost,
  }) => LocationState(
    fix: fix ?? this.fix,
    fixAt: fixAt ?? this.fixAt,
    streaming: streaming ?? this.streaming,
    lost: lost ?? this.lost,
  );
}

/// Tracks the device location stream app-wide.
///
/// A fix marks us live. Location is flagged [LocationState.lost] only on a real
/// signal: the [LocationService.availabilityStream] reports the OS location
/// service disabled or permission denied, or the position stream errors; a new
/// fix (or the service coming back) clears it. No timers live here, so a test
/// that does not dispose its `ProviderContainer` never leaves one pending.
class LocationTracker extends Notifier<LocationState> {
  StreamSubscription<LocationSample>? _positionSub;
  StreamSubscription<bool>? _availabilitySub;

  /// The last availability reported by the service. Optimistic until told
  /// otherwise, so a missing availability signal never greys out a usable fix.
  bool _available = true;

  @override
  LocationState build() {
    final LocationService service = ref.read(locationServiceProvider);
    _positionSub = service.positionStream().listen(
      _onSample,
      onError: (Object _) => _markLost(),
      cancelOnError: false,
    );
    _availabilitySub = service.availabilityStream().listen(
      _onAvailability,
      onError: (Object _) {},
    );
    ref.onDispose(() {
      unawaited(_positionSub?.cancel());
      unawaited(_availabilitySub?.cancel());
    });
    unawaited(_seed());
    return const LocationState();
  }

  /// Seeds the last known fix so follow can recenter before the first live
  /// update (and so a "show my location" tap is instant).
  Future<void> _seed() async {
    // Let build() return first (the notifier's state is not readable during it).
    await Future<void>.value();
    if (state.hasFix) {
      return;
    }
    final LocationSample? known = await ref
        .read(locationServiceProvider)
        .lastKnown();
    if (known == null || state.hasFix) {
      return;
    }
    state = LocationState(
      fix: known,
      fixAt: DateTime.now(),
      streaming: true,
      lost: !_available,
    );
  }

  void _onSample(LocationSample sample) {
    // A fix is proof we can be located, so it clears any lost/errored state.
    _available = true;
    state = LocationState(fix: sample, fixAt: DateTime.now(), streaming: true);
  }

  /// Reacts to the device's real location availability: disabled services or
  /// denied permission mean "lost" (the last fix stays, greyed out); recovery
  /// clears it so the alert does not outlive the outage.
  void _onAvailability(bool available) {
    _available = available;
    if (!available) {
      _markLost();
    } else if (state.lost) {
      state = state.copyWith(lost: false, streaming: state.hasFix);
    }
  }

  void _markLost() {
    if (!state.lost) {
      state = state.copyWith(streaming: false, lost: true);
    }
  }
}

final NotifierProvider<LocationTracker, LocationState> locationTrackerProvider =
    NotifierProvider<LocationTracker, LocationState>(LocationTracker.new);
