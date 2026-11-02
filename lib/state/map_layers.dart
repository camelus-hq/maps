import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/map_style.dart';
import 'ports.dart';

/// The active base map style (layers switcher). Mirrors the [MapService].
class MapStyleController extends Notifier<BaseMapStyle> {
  @override
  BaseMapStyle build() => BaseMapStyle.standard;

  Future<void> select(BaseMapStyle style) async {
    state = style;
    await ref.read(mapServiceProvider).setBaseStyle(style);
  }
}

final NotifierProvider<MapStyleController, BaseMapStyle> mapStyleProvider =
    NotifierProvider<MapStyleController, BaseMapStyle>(MapStyleController.new);

/// Whether the realtime traffic overlay is on.
class TrafficController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(mapServiceProvider).setTrafficEnabled(enabled);
  }

  Future<void> toggle() => set(!state);
}

final NotifierProvider<TrafficController, bool> trafficProvider =
    NotifierProvider<TrafficController, bool>(TrafficController.new);
