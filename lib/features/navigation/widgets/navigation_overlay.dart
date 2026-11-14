import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../state/config.dart';
import '../../../state/navigation.dart';
import '../../../state/sheet_anchor.dart';
import '../../map_home/widgets/map_attribution.dart';
import 'car_nav_bottom_sheet.dart';
import 'cycle_nav_bottom_sheet.dart';
import 'cycle_navigation_view.dart';
import 'drive_navigation_view.dart';
import 'nav_widgets.dart';
import 'transit_nav_bottom_sheet.dart';
import 'transit_navigation_view.dart';
import 'walk_nav_bottom_sheet.dart';
import 'walk_navigation_view.dart';

/// Active-guidance overlay.
///
/// The live map underneath is shared; only this chrome changes with the travel
/// mode — a mixed-mode journey re-skins by changing [NavState.mode] (`nav.mode`)
/// without touching the camera or the route. The trip sheet reaches the screen
/// bottom and the data attribution is pinned to its top edge, like the other
/// map sheets.
class NavigationOverlay extends ConsumerWidget {
  const NavigationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NavState nav = ref.watch(navigationControllerProvider);
    if (nav.status == NavStatus.idle) {
      return const SizedBox.shrink();
    }
    final NavigationController controller = ref.read(
      navigationControllerProvider.notifier,
    );
    final bool tracking = nav.cameraFollows && !nav.overview;
    final bool hasMapboxToken = ref.watch(appConfigProvider).hasMapboxToken;
    // The user browsed the map away from the position (a manual pan/pinch/zoom):
    // offer a prominent, one-tap way back. Overview is a deliberate route view
    // with its own control, so it does not show the pill.
    final bool showRecenter =
        !tracking &&
        !nav.overview &&
        (nav.status == NavStatus.navigating ||
            nav.status == NavStatus.rerouting);
    // Every travel mode gets its own navigation sheet over the shared chrome.
    final Widget sheet = switch (nav.mode) {
      TravelMode.drive => CarNavBottomSheet(
        nav: nav,
        tracking: tracking,
        onExit: controller.stop,
        onToggleOverview: controller.recenterOrOverview,
      ),
      TravelMode.cycle => CycleNavBottomSheet(
        nav: nav,
        tracking: tracking,
        onExit: controller.stop,
        onToggleOverview: controller.recenterOrOverview,
      ),
      TravelMode.walk => WalkNavBottomSheet(
        nav: nav,
        tracking: tracking,
        onExit: controller.stop,
        onToggleOverview: controller.recenterOrOverview,
      ),
      TravelMode.transit => TransitNavBottomSheet(
        nav: nav,
        tracking: tracking,
        onExit: controller.stop,
        onToggleOverview: controller.recenterOrOverview,
      ),
    };
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // The top chrome (banner, speed chip, side controls) respects the
          // status bar; the sheet below reaches the screen bottom.
          SafeArea(
            bottom: false,
            child: Stack(children: <Widget>[_viewFor(nav)]),
          ),
          // Sits above the resting ETA sheet (same collapsed height the side
          // controls use); when the sheet is dragged up it covers the pill.
          if (showRecenter) _RecenterPill(onPressed: controller.resumeTracking),
          sheet,
          if (hasMapboxToken) const MapAttribution(),
        ],
      ),
    );
  }

  Widget _viewFor(NavState nav) => switch (nav.mode) {
    TravelMode.drive => DriveNavigationView(nav: nav),
    TravelMode.cycle => CycleNavigationView(nav: nav),
    TravelMode.walk => WalkNavigationView(nav: nav),
    TravelMode.transit => TransitNavigationView(nav: nav),
  };
}

/// Positions the floating [NavRecenterButton] at the bottom centre, just above
/// the visible navigation sheet.
///
/// Attached to the sheet's measured top edge ([sheetAnchorProvider]) — the same
/// anchor [MapControls] and [MapAttribution] use — so it sits correctly above
/// the shorter car sheet and the taller cycling/walking/transit sheets, tracks
/// the sheet as it is dragged, and fades out once the sheet is expanded enough
/// to crowd it ([SheetAnchor.hidesChrome]).
class _RecenterPill extends ConsumerWidget {
  const _RecenterPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SheetAnchor? anchor = ref.watch(sheetAnchorProvider);
    final bool hidden = anchor == null || anchor.hidesChrome;
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      // `none` is only reached before the first measurement; the pill is hidden
      // then, so the resting position does not matter.
      bottom: (anchor ?? SheetAnchor.none).topInset + AppSpacing.lg + 0,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(child: NavRecenterButton(onPressed: onPressed)),
        ),
      ),
    );
  }
}
