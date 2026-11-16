import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_avatar.dart';
import '../atoms/play_icon_button.dart';
import '../atoms/play_pressable.dart';
import '../atoms/play_surface.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// The floating search bar at the top of the map, in play dress.
///
/// Tapping the bar itself opens search (the bar is a button, not a text field —
/// the real input lives on the search screen, matching the reference). The
/// brand mark is our own compass tile, not a copied logo.
class PlaySearchBar extends StatelessWidget {
  const PlaySearchBar({
    super.key,
    required this.onTap,
    this.hint = 'Search here',
    this.onMicTap,
    this.onAvatarTap,
    this.avatarLabel = 'You',
    this.avatarUrl,
  });

  final VoidCallback onTap;
  final String hint;
  final VoidCallback? onMicTap;
  final VoidCallback? onAvatarTap;
  final String avatarLabel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      radius: PlayRadii.pill,
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.sm,
        PlaySpace.sm,
        PlaySpace.sm,
        PlaySpace.sm,
      ),
      borderWidth: 1,
      shadow: PlayShadow.soft,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          PlaySurface(
            radius: PlayRadii.sm,
            tone: PlayTone.primary,
            shadow: PlayShadow.none,
            padding: const EdgeInsets.all(7),
            child: Icon(PlayIcons.brand, size: 20, color: colors.onTeal),
          ),
          const SizedBox(width: PlaySpace.md),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
          ),
          PlayIconButton(
            icon: PlayIcons.microphone,
            variant: PlayIconButtonVariant.plain,
            size: 40,
            iconSize: 22,
            semanticLabel: 'Voice search',
            onPressed: onMicTap,
          ),
          const SizedBox(width: PlaySpace.xs),
          PlayPressable(
            onTap: onAvatarTap,
            enabled: onAvatarTap != null,
            child: PlayAvatar(
              label: avatarLabel,
              imageUrl: avatarUrl,
              size: 36,
              tone: PlayTone.soft,
            ),
          ),
        ],
      ),
    );
  }
}

@PlayPreview(name: 'PlaySearchBar', size: Size(460, 160))
Widget playSearchBarPreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topCenter,
    child: PlaySearchBar(onTap: () {}, onMicTap: () {}, onAvatarTap: () {}),
  );
}
