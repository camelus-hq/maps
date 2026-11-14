import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/location.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../nav_style.dart';
import 'nav_widgets.dart';

/// The car guidance chrome: the two-tier instruction banner (with lane
/// guidance), a speed chip and the right-hand map controls. The ETA card and
/// trip options live in the shared [CarNavBottomSheet].
class DriveNavigationView extends ConsumerWidget {
  const DriveNavigationView({super.key, required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final NavigationController controller = ref.read(
      navigationControllerProvider.notifier,
    );
    final bool tracking = nav.cameraFollows && !nav.overview;
    final NavStyle style = NavStyle.forMode(nav.mode);
    final double? speedKmh = _speedKmh(ref);
    final double controlsBottom = _controlsBottom(context);
    return Stack(
      children: <Widget>[
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          child: NavBanner(nav: nav, style: style, imperial: imperial),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: controlsBottom,
          child: NavSideControls(
            tracking: tracking,
            onToggleOverview: controller.recenterOrOverview,
          ),
        ),
        if (style.showSpeed)
          Positioned(
            left: AppSpacing.md,
            bottom: controlsBottom,
            child: NavSpeedChip(
              limitKmh: style.speedLimitKmh,
              currentKmh: speedKmh,
              imperial: imperial,
            ),
          ),
      ],
    );
  }
}

/// The current speed in km/h from the tracked fix, when known.
double? _speedKmh(WidgetRef ref) {
  final double? metersPerSecond = ref
      .watch(locationTrackerProvider)
      .fix
      ?.speedMetersPerSecond;
  if (metersPerSecond == null || !metersPerSecond.isFinite) {
    return null;
  }
  return metersPerSecond * 3.6;
}

/// The bottom inset that keeps the controls clear of the collapsed sheet.
double _controlsBottom(BuildContext context) =>
    MediaQuery.sizeOf(context).height * 0.17 + AppSpacing.sm;
