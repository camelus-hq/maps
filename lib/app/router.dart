import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/directions/screens/endpoint_picker_screen.dart';
import '../features/map_home/screens/category_results_screen.dart';
import '../features/map_home/screens/map_home_screen.dart';
import '../features/saved/screens/saved_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/social/screens/add_friend_screen.dart';
import '../features/social/screens/friends_screen.dart';
import '../features/social/screens/manage_friends_screen.dart';
import '../features/social/screens/profile_screen.dart';
import '../state/navigation_keys.dart';

/// The default page transition: a small horizontal slide plus a fade, so every
/// pushed screen animates in the same way instead of swapping instantly.
Page<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0), // slide in from the trailing edge
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );
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
        onCategoryRoutePopped(container);
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
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const MapHomeScreen()),
        routes: <RouteBase>[
          // Nested under the map home so the results route always has the map
          // (with the pins) painted beneath it.
          GoRoute(
            path: 'category',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _categoryPage(state, context),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const SearchScreen()),
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
        path: '/profile',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(state, const ProfileScreen()),
      ),
    ],
  );
}
