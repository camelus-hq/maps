import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_surface.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// A big-number card — "12 min", "3.4 km", "14:32".
///
/// The play alternative to a Material stat tile: colour-blocked, one heavy
/// number, a tiny all-caps label, and an optional caption.
class PlayStatCard extends StatelessWidget {
  const PlayStatCard({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.tone = PlayTone.neutral,
    this.icon,
    this.expand = false,
  });

  final String value;
  final String label;
  final String? caption;
  final PlayTone tone;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = colors.tone(tone);
    final String? sub = caption;

    final Widget card = PlaySurface(
      tone: tone,
      radius: PlayRadii.md,
      padding: const EdgeInsets.all(PlaySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: palette.foreground),
                const SizedBox(width: PlaySpace.xs),
              ],
              Text(
                label.toUpperCase(),
                style: PlayType.overline.copyWith(
                  color: palette.foreground.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(value, style: PlayType.stat.copyWith(color: palette.foreground)),
          if (sub != null) ...<Widget>[
            const SizedBox(height: PlaySpace.xs),
            Text(
              sub,
              style: PlayType.caption.copyWith(
                color: palette.foreground.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );

    if (!expand) {
      return card;
    }
    return SizedBox(width: double.infinity, child: card);
  }
}

@PlayPreview(name: 'PlayStatCard', size: Size(560, 260))
Widget playStatCardPreview() {
  return PlayPreviewFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: PlayStatCard(
                  value: '12',
                  label: 'min',
                  caption: 'Arrives 14:32',
                  tone: PlayTone.soft,
                  icon: PlayIcons.clock,
                ),
              ),
              SizedBox(width: PlaySpace.md),
              Expanded(
                child: PlayStatCard(
                  value: '3.4',
                  label: 'km',
                  caption: 'via Prenzlauer Allee',
                  tone: PlayTone.mint,
                  icon: PlayIcons.route,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PlaySpace.md),
        const PlayStatCard(
          value: 'Fastest',
          label: 'route',
          caption: 'Light traffic',
          tone: PlayTone.strong,
          expand: true,
        ),
      ],
    ),
  );
}
