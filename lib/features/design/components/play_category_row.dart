import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_chip.dart';
import '../play_previews.dart';

/// One entry in a [PlayCategoryRow].
@immutable
class PlayCategoryData {
  const PlayCategoryData({
    required this.id,
    required this.label,
    required this.icon,
    this.selected = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
}

/// A horizontally scrolling strip of category chips with an optional leading
/// and trailing control (e.g. the browse-all chip).
class PlayCategoryRow extends StatelessWidget {
  const PlayCategoryRow({
    super.key,
    required this.categories,
    this.onSelect,
    this.leading,
    this.trailing,
    this.height = 52,
  });

  final List<PlayCategoryData> categories;

  /// Called with the tapped category id.
  final ValueChanged<String>? onSelect;
  final Widget? leading;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<String>? select = onSelect;
    final Widget? leadingWidget = leading;
    final Widget? trailingWidget = trailing;
    final List<Widget> children = <Widget>[];

    if (leadingWidget != null) {
      children.add(leadingWidget);
      children.add(const SizedBox(width: PlaySpace.sm));
    }
    for (int i = 0; i < categories.length; i++) {
      final PlayCategoryData category = categories[i];
      children.add(
        PlayChip(
          label: category.label,
          icon: category.icon,
          selected: category.selected,
          onTap: select == null ? null : () => select(category.id),
        ),
      );
      if (i < categories.length - 1) {
        children.add(const SizedBox(width: PlaySpace.sm));
      }
    }
    if (trailingWidget != null) {
      children.add(const SizedBox(width: PlaySpace.sm));
      children.add(trailingWidget);
    }

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
        children: children,
      ),
    );
  }
}

@PlayPreview(name: 'PlayCategoryRow', size: Size(560, 130))
Widget playCategoryRowPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PlayCategoryRow(
              categories: const <PlayCategoryData>[
                PlayCategoryData(
                  id: 'parks',
                  label: 'Parks',
                  icon: Icons.park,
                  selected: true,
                ),
                PlayCategoryData(
                  id: 'cafes',
                  label: 'Cafés',
                  icon: Icons.local_cafe,
                ),
                PlayCategoryData(
                  id: 'water',
                  label: 'Water',
                  icon: Icons.water_drop,
                ),
                PlayCategoryData(
                  id: 'fuel',
                  label: 'Fuel',
                  icon: Icons.local_gas_station,
                ),
                PlayCategoryData(
                  id: 'atms',
                  label: 'ATMs',
                  icon: Icons.account_balance,
                ),
              ],
              trailing: PlayChip(label: 'More', icon: Icons.tune, onTap: () {}),
            ),
            const SizedBox(height: PlaySpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
              child: Text(
                'scrolls horizontally • one selected at a time',
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        );
      },
    ),
  );
}
