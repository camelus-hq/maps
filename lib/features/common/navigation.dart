import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
