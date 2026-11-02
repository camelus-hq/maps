import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/directions/screens/endpoint_picker_screen.dart';
import '../features/map_home/screens/map_home_screen.dart';
import '../features/saved/screens/saved_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/social/screens/add_friend_screen.dart';
import '../features/social/screens/friends_screen.dart';
import '../features/social/screens/manage_friends_screen.dart';
import '../features/social/screens/profile_screen.dart';
import '../state/navigation_keys.dart';

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
        builder: (BuildContext context, GoRouterState state) =>
            const MapHomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) =>
            const SearchScreen(),
      ),
      GoRoute(
        path: '/directions/endpoint',
        builder: (BuildContext context, GoRouterState state) =>
            const EndpointPickerScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (BuildContext context, GoRouterState state) =>
            const SavedScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (BuildContext context, GoRouterState state) =>
            const FriendsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'manage',
            builder: (BuildContext context, GoRouterState state) =>
                const ManageFriendsScreen(),
          ),
          GoRoute(
            path: 'add',
            builder: (BuildContext context, GoRouterState state) =>
                const AddFriendScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
    ],
  );
}
