import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// A tiny all-caps status tag ("LIVE", "OPEN", "3 MIN").
///
/// Deliberately not a chip: no tap, no shadow, just a colour-coded capsule that
/// sits inside a card or next to a title.
class PlayTag extends StatelessWidget {
  const PlayTag({
    super.key,
    required this.label,
    this.tone = PlayTone.primary,
    this.icon,
    this.filled = true,
  });

  final String label;
  final PlayTone tone;
  final IconData? icon;

  /// Filled (solid tone) or outlined (tone ink on transparent).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = colors.tone(tone);
    final Color foreground = filled ? palette.foreground : palette.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? palette.background : const Color(0x00000000),
        borderRadius: BorderRadius.circular(PlayRadii.xs),
        border: filled
            ? null
            : Border.all(color: palette.background, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PlaySpace.sm,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: PlaySpace.xs),
            ],
            Text(
              label.toUpperCase(),
              style: PlayType.overline.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayTag', size: Size(560, 220))
Widget playTagPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              spacing: PlaySpace.sm,
              runSpacing: PlaySpace.sm,
              children: <Widget>[
                const PlayTag(label: 'Live', icon: PlayIcons.liveDot),
                const PlayTag(label: 'Open', tone: PlayTone.mint),
                const PlayTag(label: '3 min', tone: PlayTone.lemon),
                const PlayTag(label: 'Closed', tone: PlayTone.coral),
                const PlayTag(label: 'Fastest', tone: PlayTone.soft),
                const PlayTag(
                  label: 'Scenic',
                  tone: PlayTone.primary,
                  filled: false,
                ),
              ],
            ),
            const SizedBox(height: PlaySpace.xl),
            Text(
              'tags are colour-coded by tone',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        );
      },
    ),
  );
}
