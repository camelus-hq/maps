import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_icons.dart';
import '../play_previews.dart';
import 'play_pressable.dart';
import 'play_tag.dart';

/// A flat, tappable list row — the play replacement for `ListTile` in feed
/// lists, sheets and settings.
///
/// An optional leading glyph, a title with an optional subtitle, and a trailing
/// widget (a chevron is added automatically for a navigation row).
class PlayRow extends StatelessWidget {
  const PlayRow({
    super.key,
    required this.label,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  /// Shows a trailing chevron when there is no explicit [trailing] and the row
  /// is tappable.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final String? sub = subtitle;
    final Widget? trailingWidget = trailing;
    final bool tappable = enabled && onTap != null;
    final Widget? end =
        trailingWidget ??
        (tappable && showChevron
            ? Icon(PlayIcons.next, size: 18, color: colors.inkFaint)
            : null);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: PlayPressable(
        enabled: tappable,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PlaySpace.xs,
            vertical: PlaySpace.md,
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 22,
                  color: tappable ? colors.ink : colors.inkMuted,
                ),
                const SizedBox(width: PlaySpace.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayType.bodyStrong.copyWith(color: colors.ink),
                    ),
                    if (sub != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PlayType.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (end != null) ...<Widget>[
                const SizedBox(width: PlaySpace.sm),
                end,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayRow', size: Size(420, 300))
Widget playRowPreview() {
  return PlayPreviewFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PlayRow(icon: PlayIcons.nearby, label: 'Nearby'),
        PlayRow(
          icon: PlayIcons.friends,
          label: 'Friends',
          subtitle: '3 sharing live',
          onTap: () {},
        ),
        const PlayRow(
          icon: PlayIcons.saved,
          label: 'Saved',
          trailing: PlayTag(label: '12'),
        ),
        const PlayRow(
          icon: PlayIcons.contributePlace,
          label: 'Contributions are not available yet',
          subtitle: 'Place suggestions and edits come later',
          enabled: false,
        ),
      ],
    ),
  );
}
