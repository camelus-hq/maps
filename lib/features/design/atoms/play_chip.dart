import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_surface.dart';

/// A selectable pill — the play replacement for `FilterChip`/`ChoiceChip`.
///
/// Unselected it is a white pill with a hairline; selected it flips to the
/// inverted "strong" block so the active category reads instantly in both
/// brightnesses. No checkmark, no Material state layers.
class PlayChip extends StatelessWidget {
  const PlayChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Optional widget after the label (a count, a close glyph…).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = selected
        ? colors.tone(PlayTone.strong)
        : colors.tone(PlayTone.neutral);
    final Widget? trailingWidget = trailing;

    return PlaySurface(
      radius: PlayRadii.pill,
      padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
      shadow: selected ? PlayShadow.none : PlayShadow.soft,
      borderWidth: selected ? 0 : 1,
      backgroundColor: palette.background,
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: palette.foreground),
              const SizedBox(width: PlaySpace.sm),
            ],
            Text(
              label,
              style: PlayType.bodyStrong.copyWith(color: palette.foreground),
            ),
            if (trailingWidget != null) ...<Widget>[
              const SizedBox(width: PlaySpace.sm),
              trailingWidget,
            ],
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayChip', size: Size(560, 240))
Widget playChipPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: PlaySpace.sm,
              runSpacing: PlaySpace.sm,
              children: <Widget>[
                const PlayChip(label: 'Cafés', icon: Icons.local_cafe),
                const PlayChip(
                  label: 'Parks',
                  icon: Icons.park,
                  selected: true,
                ),
                PlayChip(
                  label: 'Water',
                  icon: Icons.water_drop,
                  trailing: Text(
                    '12',
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ),
                PlayChip(
                  label: 'Groceries',
                  icon: Icons.shopping_basket,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: PlaySpace.lg),
            Text(
              'selected = the inverted block',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        );
      },
    ),
  );
}
