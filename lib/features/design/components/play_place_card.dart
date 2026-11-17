import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_icon_button.dart';
import '../atoms/play_surface.dart';
import '../atoms/play_tag.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// A place / search-result row in play dress.
///
/// A tonal icon tile, a title and a muted subtitle, some tags, and a trailing
/// action — the shape shared by search results, saved places and recents. It is
/// deliberately one card rather than a Material `ListTile`.
class PlayPlaceCard extends StatelessWidget {
  const PlayPlaceCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.tone = PlayTone.soft,
    this.tags = const <Widget>[],
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final IconData icon;
  final String? subtitle;

  /// Tone of the leading icon tile.
  final PlayTone tone;
  final List<Widget> tags;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors tile = colors.tone(tone);
    final String? sub = subtitle;
    final Widget? trailingWidget = trailing;

    return PlaySurface(
      radius: PlayRadii.md,
      padding: const EdgeInsets.all(PlaySpace.md),
      borderWidth: selected ? 2 : 1,
      borderColor: selected ? colors.primary : null,
      shadow: PlayShadow.soft,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          PlaySurface(
            radius: PlayRadii.sm,
            padding: const EdgeInsets.all(PlaySpace.md),
            shadow: PlayShadow.none,
            backgroundColor: tile.background,
            child: Icon(icon, size: 22, color: tile.foreground),
          ),
          const SizedBox(width: PlaySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PlayType.subtitle.copyWith(color: colors.ink),
                ),
                if (sub != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PlaySpace.sm),
                  Wrap(
                    spacing: PlaySpace.xs,
                    runSpacing: PlaySpace.xs,
                    children: tags,
                  ),
                ],
              ],
            ),
          ),
          if (trailingWidget != null) ...<Widget>[
            const SizedBox(width: PlaySpace.sm),
            trailingWidget,
          ],
        ],
      ),
    );
  }
}

@PlayPreview(name: 'PlayPlaceCard', size: Size(520, 420))
Widget playPlaceCardPreview() {
  return PlayPreviewFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PlayPlaceCard(
          title: 'The Barn Coffee',
          subtitle: 'Coffee shop · Torstraße 12',
          icon: PlayIcons.cafe,
          tone: PlayTone.pink,
          tags: const <Widget>[
            PlayTag(label: '4.8', tone: PlayTone.lemon),
            PlayTag(label: 'Open', tone: PlayTone.mint),
          ],
          trailing: const PlayIconButton(
            icon: PlayIcons.directions,
            variant: PlayIconButtonVariant.primary,
            size: 44,
            semanticLabel: 'Directions',
          ),
          onTap: () {},
        ),
        const SizedBox(height: PlaySpace.md),
        PlayPlaceCard(
          title: 'Mauerpark',
          subtitle: '1.2 km · 16 min walk',
          icon: PlayIcons.park,
          tone: PlayTone.mint,
          selected: true,
          trailing: const PlayIconButton(
            icon: PlayIcons.save,
            size: 44,
            semanticLabel: 'Save',
          ),
        ),
      ],
    ),
  );
}
