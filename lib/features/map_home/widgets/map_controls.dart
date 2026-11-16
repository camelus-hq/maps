import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/commands/commands_provider.dart';
import '../../../state/follow.dart';
import '../../../state/location.dart';
import '../../../state/map_camera.dart';
import '../../../state/sheet_anchor.dart';
import '../../design/play.dart';
import 'layers_sheet.dart';

/// My-location and compass controls floating above the map, in the play style.
///
/// Buttons dispatch the same command ids the control channel uses, so the UI
/// and agents share one code path. The column is attached to the visible bottom
/// sheet ([sheetAnchorProvider]) so it tracks the sheet's top edge as it is
/// dragged, and fades out once the sheet grows past the point where it would
/// crowd the sheet's content (see [SheetAnchor.hidesChrome]).
class MapControls extends ConsumerWidget {
  const MapControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bearing =
        ref.watch(
          mapCameraProvider.select((camera) => camera.value?.bearing ?? 0),
        ) ??
        0;
    final bool following = ref.watch(followModeProvider);
    final LocationState location = ref.watch(locationTrackerProvider);
    // Location unavailable: OS services off / permission denied / stream error.
    // The last known location (if any) stays on the map, greyed out.
    final bool gpsLost = location.lost;
    final MapOrientation orientation = ref.watch(mapOrientationProvider);
    // In north mode the needle is upright even if a stale bearing lingers; in
    // heading mode it rotates so it keeps pointing north.
    final bool northLocked = orientation == MapOrientation.north;
    final double needle = northLocked ? 0 : -bearing * math.pi / 180;
    final bool showCompass = following || bearing.abs() > 0.5;
    final SheetAnchor? anchor = ref.watch(sheetAnchorProvider);
    final bool hidden = anchor == null || anchor.hidesChrome;
    return Positioned(
      right: PlaySpace.lg,
      // `none` is only reached before the first measurement; the chrome is
      // hidden then, so the resting position does not matter.
      bottom: (anchor ?? SheetAnchor.none).topInset + PlaySpace.lg,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PlayIconButton(
                icon: PlayIcons.layers,
                size: 48,
                semanticLabel: 'Layers',
                onPressed: () => unawaited(showLayersSheet(context)),
              ),
              const SizedBox(height: PlaySpace.sm),
              if (showCompass) ...<Widget>[
                PlayIconButton(
                  icon: PlayIcons.navigation,
                  size: 48,
                  rotation: needle,
                  semanticLabel: following
                      ? (northLocked
                            ? 'North up — tap to follow the direction you face'
                            : 'Direction up — tap to keep north up')
                      : 'Reset bearing',
                  onPressed: () => unawaited(
                    ref
                        .read(commandRegistryProvider)
                        .dispatch(
                          // While following, the compass toggles the
                          // orientation; otherwise it just snaps the map back
                          // to north.
                          following ? 'map.orientation' : 'map.resetBearing',
                          const <String, Object?>{},
                        ),
                  ),
                ),
                const SizedBox(height: PlaySpace.sm),
              ],
              PlayIconButton(
                icon: gpsLost ? PlayIcons.locationLost : PlayIcons.locate,
                size: 48,
                active: following && !gpsLost,
                alert: gpsLost,
                semanticLabel: gpsLost
                    ? 'Location unavailable — showing your last known location'
                    : following
                    ? 'Following your location'
                    : 'Show my location',
                onPressed: () => unawaited(
                  ref
                      .read(commandRegistryProvider)
                      .dispatch(
                        'map.followMyLocation',
                        const <String, Object?>{},
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@PlayPreview(name: 'MapControls', size: Size(140, 340))
Widget mapControlsPreview() {
  return PlayPreviewFrame(
    child: PlayMapControlRail(
      controls: <PlayMapControl>[
        PlayMapControl(
          icon: PlayIcons.layers,
          semanticLabel: 'Layers',
          onTap: () {},
        ),
        PlayMapControl(
          icon: PlayIcons.navigation,
          semanticLabel: 'Reset bearing',
          rotation: 0.4,
          onTap: () {},
        ),
        const PlayMapControl(
          icon: PlayIcons.locate,
          semanticLabel: 'Following your location',
          active: true,
        ),
        const PlayMapControl(
          icon: PlayIcons.locationLost,
          semanticLabel: 'Location unavailable',
          alert: true,
        ),
      ],
    ),
  );
}
