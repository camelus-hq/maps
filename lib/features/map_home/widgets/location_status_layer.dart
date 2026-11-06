import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/location.dart';

/// Invisible layer that ages the device-location state.
///
/// The [LocationTracker] owns no timer (so tests never leak one); this widget
/// pings it once a second while the map is on screen, marking the GPS signal
/// lost when fixes stop arriving. It draws nothing and never takes a gesture.
class LocationStatusLayer extends ConsumerStatefulWidget {
  const LocationStatusLayer({super.key});

  @override
  ConsumerState<LocationStatusLayer> createState() =>
      _LocationStatusLayerState();
}

class _LocationStatusLayerState extends ConsumerState<LocationStatusLayer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer _) => ref.read(locationTrackerProvider.notifier).checkStale(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
