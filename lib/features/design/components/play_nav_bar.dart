import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_pressable.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// One destination in a [PlayNavBar].
@immutable
class PlayNavDestination {
  const PlayNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The play bottom navigation bar.
///
/// Not a Material `NavigationBar`: each destination is an icon-over-label cell
/// that lifts onto a soft pill when selected, and the bar's surface paints
/// behind the bottom system inset itself (so no separate `SafeArea`).
class PlayNavBar extends StatelessWidget {
  const PlayNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PlayNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return ColoredBox(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PlaySpace.sm,
              vertical: PlaySpace.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                for (int i = 0; i < destinations.length; i++)
                  _Destination(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final PlayNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = colors.tone(
      selected ? PlayTone.soft : PlayTone.neutral,
    );
    final Color foreground = selected ? palette.foreground : colors.inkMuted;
    return PlayPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: PlaySpace.lg,
          vertical: PlaySpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.background : const Color(0x00000000),
          borderRadius: BorderRadius.circular(PlayRadii.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 22,
              color: foreground,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: PlayType.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayNavBar', size: Size(420, 130))
Widget playNavBarPreview() {
  return Align(
    alignment: Alignment.bottomCenter,
    child: PlayNavBar(
      selectedIndex: 0,
      onSelected: (int _) {},
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
  );
}
