import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../state/home.dart';
import 'home_feed_sheet.dart';

/// The map-home shell when no place/directions sheet is open: the Explore feed
/// above the bottom navigation bar (Explore / You / Contribute).
///
/// Replaced by the place or directions sheet when one is open, and hidden during
/// guidance — mirroring Google Maps.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeTab tab = ref.watch(homeTabProvider);
    return Column(
      children: <Widget>[
        const Expanded(child: HomeFeedSheet()),
        // [NavigationBar] paints its own background over the bottom safe area,
        // so it is glued straight onto the sheet — no wrapping [SafeArea], which
        // would leave a transparent strip for the map to shine through.
        //
        // It also has to be told to ignore the *top* padding: the bar is at the
        // bottom of the screen, but its internal [SafeArea] would otherwise
        // reserve the status-bar inset at the top of the bar, opening an empty
        // gap between the sheet and the destinations.
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (int index) => ref
                .read(homeTabProvider.notifier)
                .select(HomeTab.values[index]),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'You',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_location_alt_outlined),
                selectedIcon: Icon(Icons.add_location_alt),
                label: 'Contribute',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
