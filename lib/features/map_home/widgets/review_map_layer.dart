import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/camera.dart';
import '../../../state/map_camera.dart';
import '../../../state/ports.dart';
import '../../../state/reviews.dart';

/// Invisible layer that keeps the map's review badges in sync with the camera.
///
/// It has no visual of its own: it measures the map viewport, reads the live
/// camera and asks [ReviewMarkersController] for the reviews inside the visible
/// rectangle (which queries by geohash). Returning a transparent box means it
/// never steals a gesture from the map.
class ReviewMapLayer extends ConsumerWidget {
  const ReviewMapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Camera camera =
        ref.watch(mapCameraProvider).value ??
        ref.read(mapServiceProvider).camera;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(constraints.maxWidth, constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          ref.read(reviewMarkersProvider.notifier).update(camera, viewport);
        });
        return const SizedBox.shrink();
      },
    );
  }
}
