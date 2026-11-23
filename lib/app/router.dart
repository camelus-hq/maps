import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/deep_link.dart';
import '../features/common/deep_link_route_host.dart';
import '../features/directions/screens/endpoint_picker_screen.dart';
import '../features/feedback/screens/feedback_screen.dart';
import '../features/map_home/screens/category_results_screen.dart';
import '../features/map_home/screens/map_home_screen.dart';
import '../features/saved/screens/saved_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/social/screens/add_friend_screen.dart';
import '../features/social/screens/friends_screen.dart';
import '../features/social/screens/manage_friends_screen.dart';
import '../features/social/screens/profile_screen.dart';
import '../features/trips/screens/trip_detail_screen.dart';
import '../features/trips/screens/trips_screen.dart';
import '../state/navigation_keys.dart';
import '../state/place.dart';
import '../state/route.dart';

/// The default page transition: a small horizontal slide, so every pushed screen
/// animates in the same way instead of swapping instantly.
///
/// Deliberately **no fade**. A full-screen `OpacityLayer` makes the engine
/// re-composite the whole pushed page on every animation frame; with Impeller
/// (the Android default, and it has no raster cache) that costs a large multiple
/// of a normal frame, so pushing the search page visibly stuttered — worse
/// because its text field autofocuses, so the IME opens and re-lays-out the page
/// across the same frames. A transform-only slide keeps the motion and draws the
/// page once per frame.
Page<void> _page(GoRouterState state, Widget child) {
  return MaterialPage<void>(key: state.pageKey, child: child);
}

/// Runs a route's pop handler once the current frame is done building.
///
/// `Page.onPopInvoked` is not only called for a real pop (the back gesture):
/// when the Navigator replaces its page list — e.g. the URL mirror's `go('/')`
/// dropping the `/place` or `/category` overlay — go_router reports the removal
/// from `NavigatorState.didUpdateWidget`. Clearing a provider there throws
/// Riverpod's "Tried to modify a provider while the widget tree was building",
/// so the pop work is scheduled as a microtask, which runs after the frame's
/// synchronous build/finalize pass has finished (unlike a timer, it never leaves
/// a pending timer behind for tests).
void _runOnPop(void Function() work) {
  scheduleMicrotask(work);
}

/// The category-results page: a non-modal route that fades up over the map.
///
/// A normal [Page]/[ModalRoute] always lays down a full-screen [ModalBarrier],
/// which would swallow every tap meant for the map behind it. This route is a
/// plain [TransitionRoute] — no barrier — so the map home stays visible *and*
/// interactive (pan, pinch, tap a chip) while the results sheet floats on top,
/// exactly as the sheet did before it became a route. Being a route is what
/// gives the browse a back gesture and a `ui.back`/AppBar pop: [onPopInvoked]
/// clears the browse when it is dismissed.
///
/// The transition is a **fade only**, never a slide: a slide would translate the
/// sheet while it measures itself, so the chrome would anchor to the offset
/// position and only snap back on the next drag (the same reason the map-home
/// sheet switcher fades — see `plan/STATUS.md`, owner feedback 12).
Page<void> _categoryPage(GoRouterState state, BuildContext context) {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  return _OverlayPage<void>(
    key: state.pageKey,
    builder: (BuildContext context) => const CategoryResultsScreen(),
    onPopInvoked: (bool didPop, void result) {
      if (didPop) {
        _runOnPop(() => onCategoryRoutePopped(container));
      }
    },
  );
}

/// A transparent, barrier-free overlay route for a sheet that is *rendered by*
/// the map home (the place details and the directions preview both live off
/// provider state). It exists purely so the URL carries the sheet and the back
/// gesture closes it: [onPopInvoked] clears the matching state, and the map
/// still receives every gesture because the route paints nothing.
Page<void> _sheetRoutePage(
  GoRouterState state,
  BuildContext context, {
  required DeepLink? link,
  required void Function(ProviderContainer container) onPopped,
}) {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  return _OverlayPage<void>(
    key: state.pageKey,
    builder: (BuildContext context) =>
        DeepLinkRouteHost(link: link, child: const SizedBox.shrink()),
    onPopInvoked: (bool didPop, void result) {
      if (didPop) {
        _runOnPop(() => onPopped(container));
      }
    },
  );
}

class _OverlayPage<T> extends Page<T> {
  const _OverlayPage({required this.builder, super.key, super.onPopInvoked});

  final WidgetBuilder builder;

  @override
  Route<T> createRoute(BuildContext context) =>
      _OverlayTransitionRoute<T>(page: this);
}

class _OverlayTransitionRoute<T> extends TransitionRoute<T> {
  _OverlayTransitionRoute({required this.page}) : super(settings: page);

  final _OverlayPage<T> page;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  bool get opaque => false;

  /// Edge-swipe/predictive back is enabled whenever there is something to go
  /// back to (a plain route has no form vetoes to consult).
  @override
  bool get popGestureEnabled => !isFirst && !willHandlePopInternally;

  @override
  Iterable<OverlayEntry> createOverlayEntries() sync* {
    yield OverlayEntry(
      builder: (BuildContext context) {
        final Animation<double>? animation = this.animation;
        final Widget child = page.builder(context);
        if (animation == null) {
          return child;
        }
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // Fade only — a slide would shift the sheet's measured geometry while
        // it reports its anchor (the chrome would attach to the offset).
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}

/// App-level routes only (deep links, settings). Feature flows such as
/// search → place → directions are sheet states in L3, not routes
/// (plan/architecture.md §6).
GoRouter buildAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (BuildContext context, GoRouterState state) {
          // The map home applies the `at=` view from any of its URLs; the
          // nested sheet routes apply the rest of their own link. A URL that is
          // not one of the map's routes (a picker, settings, …) leaves it be.
          final DeepLink? link = DeepLink.parse(state.uri);
          return _page(
            state,
            DeepLinkRouteHost(
              link: link == null ? null : DeepLink.map(view: link.view),
              child: const MapHomeScreen(),
            ),
          );
        },
        routes: <RouteBase>[
          // Nested under the map home so the results route always has the map
          // (with the pins) painted beneath it.
          GoRoute(
            path: 'category',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _categoryPage(state, context),
          ),
          // Deep-linkable sheets. These render nothing (the map home draws the
          // sheet from state); they carry the URL and make the back gesture
          // close the sheet, exactly like `/category`.
          GoRoute(
            path: 'place/:type/:id',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _sheetRoutePage(
                  state,
                  context,
                  link: state.uri.path.startsWith('/place')
                      ? DeepLink.parse(state.uri)
                      : null,
                  onPopped: (ProviderContainer container) =>
                      container.read(selectedPlaceProvider.notifier).clear(),
                ),
          ),
          GoRoute(
            path: 'place/:id',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _sheetRoutePage(
                  state,
                  context,
                  link: state.uri.path.startsWith('/place')
                      ? DeepLink.parse(state.uri)
                      : null,
                  onPopped: (ProviderContainer container) =>
                      container.read(selectedPlaceProvider.notifier).clear(),
                ),
          ),
          GoRoute(
            path: 'directions',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _sheetRoutePage(
                  state,
                  context,
                  link: state.uri.path == '/directions'
                      ? DeepLink.parse(state.uri)
                      : null,
                  onPopped: (ProviderContainer container) =>
                      container.read(routeControllerProvider.notifier).clear(),
                ),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String? query = state.uri.queryParameters['q'];
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: DeepLinkRouteHost(
              // The search screen seeds its own query; the host only applies
              // the `at=` view from the URL.
              link: state.uri.path == '/search'
                  ? DeepLink.parse(state.uri)
                  : null,
              child: SearchScreen(
                initialQuery: (query != null && query.trim().isNotEmpty)
                    ? query
                    : null,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/directions/endpoint',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const EndpointPickerScreen()),
      ),
      GoRoute(
        path: '/saved',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const SavedScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/feedback',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          return _page(
            state,
            FeedbackScreen(screenshot: extra is Uint8List ? extra : null),
          );
        },
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const FriendsScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: 'manage',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(state, const ManageFriendsScreen()),
          ),
          GoRoute(
            path: 'add',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(state, const AddFriendScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/trips',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const TripsScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            pageBuilder: (BuildContext context, GoRouterState state) => _page(
              state,
              TripDetailScreen(tripId: state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const ProfileScreen()),
      ),
    ],
  );
}
