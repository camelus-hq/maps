import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The map viewport size in logical pixels, reported by an invisible layer on
/// the map home.
///
/// `null` until the map has been laid out once. Search uses it (with the live
/// camera) to bound a POI category query to what is on screen; when it is
/// missing the data layer falls back to a small fixed radius.
class MapViewportController extends Notifier<Size?> {
  @override
  Size? build() => null;

  /// Records the measured viewport, ignoring degenerate sizes.
  void report(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    if (state == size) {
      return;
    }
    state = size;
  }
}

final NotifierProvider<MapViewportController, Size?> mapViewportProvider =
    NotifierProvider<MapViewportController, Size?>(MapViewportController.new);
