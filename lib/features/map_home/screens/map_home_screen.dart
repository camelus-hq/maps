import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place.dart';
import '../../../state/config.dart';
import '../../../state/home.dart';
import '../../../state/map_taps.dart';
import '../../../state/navigation.dart';
import '../../../state/place.dart';
import '../../../state/reviews.dart';
import '../../../state/route.dart';
import '../../../state/settings.dart';
import '../../../state/social.dart';
import '../../directions/screens/directions_sheet.dart';
import '../../directions/widgets/directions_endpoint_card.dart';
import '../../navigation/widgets/navigation_overlay.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../place_details/widgets/place_details_sheet.dart';
import '../../reviews/widgets/write_review_sheet.dart';
import '../../social/screens/friend_location_sheet.dart';
import '../../social/widgets/friends_chip.dart';
import '../widgets/category_chips.dart';
import '../widgets/category_results_sheet.dart';
import '../widgets/friend_review_chip.dart';
import '../widgets/home_shell.dart';
import '../widgets/map_attribution.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_surface.dart';
import '../widgets/map_viewport_layer.dart';
import '../widgets/review_map_layer.dart';
import '../widgets/search_area_chip.dart';
import '../widgets/search_bar_pill.dart';

/// The persistent map-home shell: map surface, search bar, category chips and a
/// bottom sheet — replaced by the place/directions sheet or active guidance.
class MapHomeScreen extends ConsumerWidget {
  const MapHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First run: show the location rationale before the map.
    if (ref.watch(onboardingSeenProvider).value == false) {
      return const OnboardingScreen();
    }
    final Place? selected = ref.watch(selectedPlaceProvider);
    final RouteState routeState = ref.watch(routeControllerProvider);
    final String? category = ref.watch(selectedCategoryProvider);
    // While the pushed results route is open, that route owns the sheet.
    final bool categoryRouteOpen = ref.watch(categoryRouteOpenProvider);
    final String? friend = ref.watch(selectedFriendProvider);
    final ReviewComposerState composer = ref.watch(reviewComposerProvider);
    final bool composing = composer.isOpen;
    final NavState nav = ref.watch(navigationControllerProvider);
    final bool navigating = nav.status != NavStatus.idle;
    // Keeps the saved-place star markers in sync while the map is shown.
    ref.watch(savedMarkersProvider);
    // Keeps the live friend badges in sync while the map is shown.
    ref.watch(friendMarkersProvider);
    // Routes map taps (result markers + native POIs) into the place flow.
    ref.watch(mapTapProvider);

    return Scaffold(
      // The map must stay put while the soft keyboard is open. With the default
      // (true) the whole body — including the native Mapbox platform view —
      // would shrink by the keyboard inset and the map would jump up whenever a
      // text field appears anywhere above it (e.g. the search screen, which is
      // pushed on top of this route while this one stays mounted). Sheets that
      // own a text field lift themselves above the keyboard instead.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const MapSurface(),
          // Measures the map viewport (used to bound POI searches to what is
          // on screen). Invisible.
          const MapViewportLayer(),
          // Measures the viewport and keeps the review badges in sync with the
          // camera (queries only what is on screen). Invisible.
          const ReviewMapLayer(),
          if (!navigating) ...<Widget>[
            if (!composing)
              SafeArea(
                bottom: false,
                child: routeState.status != RouteStatus.idle
                    // Directions: the search bar is replaced by the
                    // start/stop/destination card that overhangs the map. It is
                    // top-aligned so the transparent Stack region below it still
                    // passes map gestures through.
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            0,
                          ),
                          child: const DirectionsEndpointCard(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                              0,
                            ),
                            child: SearchBarPill(
                              onTap: () => context.push('/search'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const CategoryChips(),
                          const SizedBox(height: AppSpacing.xs),
                          const FriendReviewChip(),
                          const SearchAreaChip(),
                        ],
                      ),
              ),
            // The sheet is measured by [MapSheet] (each sheet wraps its
            // `DraggableScrollableSheet` in it) so the floating chrome below can
            // attach to its top edge. Transition with a fade only — a slide
            // would translate the sheet's measured region while it animates, and
            // the chrome would briefly (and, after settling, incorrectly) anchor
            // to the offset position.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: categoryRouteOpen
                  // The results route is showing the sheet; the map home holds
                  // nothing so exactly one sheet reports the chrome anchor and
                  // the chrome re-anchors when the route pops.
                  ? const SizedBox.shrink()
                  : _sheet(composing, selected, routeState, category, friend),
            ),
            if (!(routeState.isTransit && routeState.transitDetailOpen))
              const MapControls(),
            if (ref.watch(appConfigProvider).hasMapboxToken)
              const MapAttribution(),
          ],
          if (navigating) const NavigationOverlay(),
        ],
      ),
    );
  }

  /// The active bottom sheet: review composer > directions > place > friend >
  /// category > home.
  Widget _sheet(
    bool composing,
    Place? selected,
    RouteState routeState,
    String? category,
    String? friend,
  ) {
    if (composing) {
      return const WriteReviewSheet(key: ValueKey<String>('write-review'));
    }
    if (routeState.status != RouteStatus.idle) {
      return const DirectionsSheet(key: ValueKey<String>('directions'));
    }
    if (selected != null) {
      return PlaceDetailsSheet(
        key: ValueKey<String>('place-${selected.id}'),
        place: selected,
      );
    }
    if (friend != null) {
      return FriendLocationSheet(
        key: ValueKey<String>('friend-$friend'),
        pubkey: friend,
      );
    }
    if (category != null) {
      return CategoryResultsSheet(key: ValueKey<String>('category-$category'));
    }
    return const HomeShell(key: ValueKey<String>('home'));
  }
}
