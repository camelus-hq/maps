import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/travel_mode.dart';
import '../../../state/config.dart';
import '../../../state/navigation.dart';
import '../../map_home/widgets/map_attribution.dart';
import 'cycle_navigation_view.dart';
import 'drive_navigation_view.dart';
import 'nav_bottom_sheet.dart';
import 'transit_navigation_view.dart';
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
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // The top chrome (banner, speed chip, side controls) respects the
          // status bar; the sheet below reaches the screen bottom.
          SafeArea(
            bottom: false,
            child: Stack(children: <Widget>[_viewFor(nav)]),
          ),
          NavBottomSheet(
            nav: nav,
            tracking: tracking,
            onExit: controller.stop,
            onToggleOverview: controller.toggleOverview,
          ),
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
