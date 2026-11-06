import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/location_sample.dart';
import 'ports.dart';

/// Live device-location presence for the map.
///
/// One subscription shared by every consumer (follow, guidance, the location
/// puck) so the GNSS stream is opened once, and one place that answers "do we
/// currently have a signal?" — which the follow button and the (greyed) last
/// known location puck reflect.
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

  /// True while fixes are arriving (or were seeded) recently.
  final bool streaming;

  /// True when we have a fix but fixes stopped arriving (GPS lost) or the
  /// stream errored — the last fix is retained so it can be shown greyed out.
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
/// A fix marks us live; if no fix arrives for [staleAfter] the signal is
/// considered lost (the last fix is kept). Errors mark it lost immediately.
///
/// Staleness is evaluated by [checkStale], which the map home drives from a
/// widget-owned timer — the tracker itself owns no timer, so a test that does
/// not dispose its `ProviderContainer` never leaves one pending.
class LocationTracker extends Notifier<LocationState> {
  /// A fix older than this means the GPS signal was lost.
  static const Duration staleAfter = Duration(seconds: 8);

  StreamSubscription<LocationSample>? _sub;

  /// When tracking started, used to flag "no signal at all" after the grace.
  late final DateTime _startedAt = DateTime.now();

  @override
  LocationState build() {
    _sub = ref
        .read(locationServiceProvider)
        .positionStream()
        .listen(
          _onSample,
          onError: (Object _) => _markLost(),
          cancelOnError: false,
        );
    ref.onDispose(() {
      unawaited(_sub?.cancel());
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
    state = LocationState(fix: known, fixAt: DateTime.now(), streaming: true);
  }

  void _onSample(LocationSample sample) {
    state = LocationState(fix: sample, fixAt: DateTime.now(), streaming: true);
  }

  /// Marks the signal lost when the last fix is older than [staleAfter] — or,
  /// when no fix has ever arrived, once the tracking grace period has passed.
  ///
  /// [now] is injectable for tests. Idempotent: a no-op once already lost.
  void checkStale([DateTime? now]) {
    if (state.lost) {
      return;
    }
    final DateTime reference = now ?? DateTime.now();
    final DateTime? at = state.fixAt;
    if (at == null) {
      if (reference.difference(_startedAt) > staleAfter) {
        state = state.copyWith(streaming: false, lost: true);
      }
      return;
    }
    if (reference.difference(at) > staleAfter) {
      state = state.copyWith(streaming: false, lost: true);
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
