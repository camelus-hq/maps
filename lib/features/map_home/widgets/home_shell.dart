import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/home.dart';
import '../../design/play.dart';
import 'home_feed_sheet.dart';

/// The map-home shell when no place/directions sheet is open: the Explore feed
/// above the bottom navigation bar (Explore / You / Contribute), in the play
/// style.
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
        // The bar's own surface paints behind the bottom system inset, so it is
        // glued straight onto the sheet — no wrapping [SafeArea], which would
        // leave a transparent strip for the map to shine through.
        PlayNavBar(
          selectedIndex: tab.index,
          onSelected: (int index) =>
              ref.read(homeTabProvider.notifier).select(HomeTab.values[index]),
          destinations: const <PlayNavDestination>[
            PlayNavDestination(
              icon: PlayIcons.explore,
              selectedIcon: PlayIcons.exploreFilled,
              label: 'Explore',
            ),
            PlayNavDestination(
              icon: PlayIcons.person,
              selectedIcon: PlayIcons.personFilled,
              label: 'You',
            ),
            PlayNavDestination(
              icon: PlayIcons.contribute,
              selectedIcon: PlayIcons.contributeFilled,
              label: 'Contribute',
            ),
          ],
        ),
      ],
    );
  }
}
