import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/camera.dart';
import '../domain/entities/lat_lon.dart';
import 'ports.dart';

/// The live map camera, mirrored from the [MapService] stream.
///
/// Used by the map controls (compass/bearing). The stream is a broadcast
/// controller, so this stays idle until the map port emits.
final StreamProvider<Camera> mapCameraProvider = StreamProvider<Camera>(
  (Ref ref) => ref.watch(mapServiceProvider).cameraStream,
);

/// Long-press coordinates from the map surface (used to pick route endpoints).
final StreamProvider<LatLon> mapLongPressProvider = StreamProvider<LatLon>(
  (Ref ref) => ref.watch(mapServiceProvider).longPressStream,
);
