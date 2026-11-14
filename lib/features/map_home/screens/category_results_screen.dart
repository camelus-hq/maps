import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/place.dart';
import '../widgets/category_results_sheet.dart';

/// Clears the browse when the `/category` route is popped (the back gesture, an
/// AppBar pop, a chip deselect or the sheet's ✕).
///
/// Called from the route's `onPopInvoked` (see `lib/app/router.dart`), which
/// runs outside a widget life-cycle, so provider writes are safe here.
///
/// Skipped when a place was just selected: tapping a result opens the place
/// sheet on the map behind, and its pin must stay.
void onCategoryRoutePopped(ProviderContainer container) {
  container.read(categoryRouteOpenProvider.notifier).set(false);
  if (container.read(selectedPlaceProvider) == null &&
      container.read(selectedCategoryProvider) != null) {
    unawaited(
      container
          .read(commandRegistryProvider)
          .dispatch('search.category', const <String, Object?>{}),
    );
  }
}

/// The pushed category-results route.
///
/// It is a transparent, non-modal route (`_OverlayTransitionRoute` in
/// `lib/app/router.dart`), so the map home — still behind it with the category
/// pins drawn — shows through and stays interactive; only the results sheet is
/// painted. Being a route is what gives the browse a back gesture (and a
/// `ui.back`/AppBar pop): popping it clears the browse.
class CategoryResultsScreen extends ConsumerStatefulWidget {
  const CategoryResultsScreen({super.key});

  @override
  ConsumerState<CategoryResultsScreen> createState() =>
      _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends ConsumerState<CategoryResultsScreen> {
  @override
  void initState() {
    super.initState();
    // The map home hands its bottom sheet over to this route while it is open
    // (a single sheet reports to the chrome anchor). Deferred to after the
    // frame so we never mutate a provider during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(categoryRouteOpenProvider.notifier).set(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // No [Scaffold] and no background: the map home shows through. The stack
    // only hit-tests where the sheet actually is, so the map (and the chips)
    // behind stay interactive.
    return const Stack(
      fit: StackFit.expand,
      children: <Widget>[CategoryResultsSheet()],
    );
  }
}
