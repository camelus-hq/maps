import 'package:flutter/widgets.dart';

import '../../core/theme/play/play_colors.dart';
import '../../core/theme/play/play_tokens.dart';
import 'atoms/play_surface.dart';
import 'play_previews.dart';

/// The colour system on one page: every tone plus the semantic inks.
@PlayPreview(name: 'Play · palette', size: Size(640, 620))
Widget playPalettePreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topLeft,
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        final List<(String, Color)> semantics = <(String, Color)>[
          ('canvas', colors.canvas),
          ('surface', colors.surface),
          ('sunken', colors.surfaceSunken),
          ('line', colors.line),
          ('ink', colors.ink),
          ('inkMuted', colors.inkMuted),
          ('inkFaint', colors.inkFaint),
          ('shadow', colors.shadowSoft),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'tones',
              style: PlayType.overline.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.sm),
            Wrap(
              spacing: PlaySpace.sm,
              runSpacing: PlaySpace.sm,
              children: <Widget>[
                for (final PlayTone tone in PlayTone.values)
                  _ToneTile(tone: tone, colors: colors),
              ],
            ),
            const SizedBox(height: PlaySpace.xl),
            Text(
              'semantic',
              style: PlayType.overline.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.sm),
            Wrap(
              spacing: PlaySpace.sm,
              runSpacing: PlaySpace.sm,
              children: <Widget>[
                for (final (String, Color) entry in semantics)
                  _Swatch(name: entry.$1, color: entry.$2, colors: colors),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// The type ramp on one page.
@PlayPreview(name: 'Play · type', size: Size(560, 520))
Widget playTypePreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topLeft,
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        final List<(String, TextStyle)> ramp = <(String, TextStyle)>[
          ('display', PlayType.display),
          ('headline', PlayType.headline),
          ('title', PlayType.title),
          ('subtitle', PlayType.subtitle),
          ('bodyStrong', PlayType.bodyStrong),
          ('body', PlayType.body),
          ('caption', PlayType.caption),
          ('overline', PlayType.overline),
          ('stat', PlayType.stat),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String, TextStyle) entry in ramp) ...<Widget>[
              Text(
                entry.$1 == 'overline'
                    ? 'LIVE · OPEN · 3 MIN'
                    : '${entry.$1} · Handgloves 0123',
                style: entry.$2.copyWith(color: colors.ink),
              ),
              const SizedBox(height: PlaySpace.sm),
            ],
          ],
        );
      },
    ),
  );
}

class _ToneTile extends StatelessWidget {
  const _ToneTile({required this.tone, required this.colors});

  final PlayTone tone;
  final PlayColors colors;

  @override
  Widget build(BuildContext context) {
    final PlayToneColors palette = colors.tone(tone);
    return PlaySurface(
      radius: PlayRadii.sm,
      backgroundColor: palette.background,
      padding: const EdgeInsets.all(PlaySpace.md),
      shadow: PlayShadow.none,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              tone.name,
              style: PlayType.bodyStrong.copyWith(color: palette.foreground),
            ),
            const SizedBox(height: PlaySpace.xs),
            Text(
              '#${palette.background.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              style: PlayType.caption.copyWith(
                color: palette.foreground.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.colors,
  });

  final String name;
  final Color color;
  final PlayColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(PlayRadii.xs),
            border: Border.all(color: colors.line),
          ),
          child: const SizedBox(width: 84, height: 44),
        ),
        const SizedBox(height: PlaySpace.xs),
        Text(name, style: PlayType.caption.copyWith(color: colors.inkMuted)),
      ],
    );
  }
}
