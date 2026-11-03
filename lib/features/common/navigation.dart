import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The pushed route that shows a category browse over the (still visible) map.
const String categoryRoute = '/category';

/// Returns to the previous page, falling back to the map home when there is
/// nothing to pop (a cold start or deep link straight onto a secondary page).
///
/// Secondary pages are opened with `push`/`pushNamed` so the Android back
/// gesture, the AppBar back button and this helper all agree on the stack.
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

/// Opens the category-results route over the map so the back gesture (and the
/// AppBar back) return to it.
///
/// [replace] swaps the current page (the search screen) for the results, so
/// back always lands on the map rather than on the search list. Calling this
/// while the route is already open (a different chip) just updates the browse —
/// it does not stack a second results page.
void openCategory(BuildContext context, {bool replace = false}) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) {
    return;
  }
  if (replace) {
    unawaited(router.pushReplacement(categoryRoute));
    return;
  }
  if (router.state.uri.path == categoryRoute) {
    return; // already showing the results
  }
  unawaited(router.push(categoryRoute));
}

/// Closes the category-results route when it is open (deselecting a chip).
void closeCategory(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null || router.state.uri.path != categoryRoute) {
    return;
  }
  router.pop();
}
