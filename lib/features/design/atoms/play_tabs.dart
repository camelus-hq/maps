import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_pressable.dart';

/// A tab strip — the play replacement for Material's `TabBar`.
///
/// Each tab is a label over an animated underline that lifts in the brand
/// colour when selected, over a hairline. The parent owns the selected index
/// (no `TabController` needed).
class PlayTabs extends StatelessWidget {
  const PlayTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: _Tab(
                label: tabs[i],
                selected: i == selectedIndex,
                colors: colors,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PlayColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PlayPressable(
      onTap: onTap,
      scale: 0.97,
      child: Padding(
        padding: const EdgeInsets.only(top: PlaySpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PlayType.bodyStrong.copyWith(
                color: selected ? colors.primary : colors.inkMuted,
              ),
            ),
            const SizedBox(height: PlaySpace.sm),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 3,
              width: 30,
              decoration: BoxDecoration(
                color: selected ? colors.primary : const Color(0x00000000),
                borderRadius: BorderRadius.circular(PlayRadii.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayTabs', size: Size(420, 140))
Widget playTabsPreview() {
  return Align(
    alignment: Alignment.topCenter,
    child: PlayTabs(
      tabs: const <String>['Overview', 'Reviews', 'Photos'],
      selectedIndex: 0,
      onSelected: (int _) {},
    ),
  );
}
