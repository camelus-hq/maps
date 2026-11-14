import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/follow.dart';
import '../../../state/location.dart';
import '../../../state/map_camera.dart';
import '../../../state/sheet_anchor.dart';
import 'layers_sheet.dart';

/// My-location and compass controls floating above the map.
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
      right: AppSpacing.md,
      // `none` is only reached before the first measurement; the chrome is
      // hidden then, so the resting position does not matter.
      bottom: (anchor ?? SheetAnchor.none).topInset + AppSpacing.md,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _MapButton(
                icon: Icons.layers_outlined,
                tooltip: 'Layers',
                onPressed: () => unawaited(showLayersSheet(context)),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (showCompass) ...<Widget>[
                _MapButton(
                  icon: Icons.navigation_outlined,
                  tooltip: following
                      ? (northLocked
                            ? 'North up — tap to follow the direction you face'
                            : 'Direction up — tap to keep north up')
                      : 'Reset bearing',
                  // The needle points north, so the map orientation is readable.
                  rotation: needle,
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
                const SizedBox(height: AppSpacing.sm),
              ],
              _MapButton(
                icon: gpsLost
                    ? Icons.gps_off
                    : following
                    ? Icons.my_location
                    : Icons.location_searching,
                tooltip: gpsLost
                    ? 'Location unavailable — showing your last known location'
                    : following
                    ? 'Following your location'
                    : 'Show my location',
                active: following && !gpsLost,
                alert: gpsLost,
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

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.rotation = 0,
    this.active = false,
    this.alert = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double rotation;

  /// Filled/primary treatment for a toggled-on control (location follow), so
  /// "locked on" reads clearly against the neutral idle state.
  final bool active;

  /// Warning treatment (amber) for a problem state, e.g. a lost GPS signal.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = active
        ? scheme.onPrimary
        : alert
        ? _alertColor
        : scheme.onSurfaceVariant;
    return Material(
      color: active
          ? scheme.primary
          : alert
          ? _alertColor.withValues(alpha: 0.14)
          : scheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        icon: rotation == 0
            ? Icon(icon, color: foreground)
            : Transform.rotate(
                angle: rotation,
                child: Icon(icon, color: foreground),
              ),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// The amber used for the "location unavailable" state (readable on the light
  /// and dark surfaces).
  static const Color _alertColor = Color(0xFFDD8500);
}
