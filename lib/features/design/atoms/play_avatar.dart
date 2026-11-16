import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';

/// A round avatar: a network picture when there is one, else a monogram (or an
/// icon) on a tonal circle, with an optional presence dot.
///
/// Network images are best-effort — a hostile or broken URL falls back to the
/// monogram instead of throwing (AGENTS.md "Never crash").
class PlayAvatar extends StatelessWidget {
  const PlayAvatar({
    super.key,
    required this.label,
    this.imageUrl,
    this.icon,
    this.size = 40,
    this.tone = PlayTone.soft,
    this.dot = false,
    this.dotTone = PlayTone.mint,
    this.ring = false,
  });

  final String label;
  final String? imageUrl;
  final IconData? icon;
  final double size;
  final PlayTone tone;

  /// Shows a presence dot in the bottom-right corner.
  final bool dot;
  final PlayTone dotTone;

  /// Draws a canvas-coloured ring, so overlapping avatars read apart.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = colors.tone(tone);
    final Widget face = SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: _face(context, palette)),
    );

    Widget avatar = face;
    if (ring) {
      avatar = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.canvas, width: 2),
        ),
        child: face,
      );
    }
    if (!dot) {
      return avatar;
    }
    final double dotSize = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: avatar),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: colors.tone(dotTone).background,
                shape: BoxShape.circle,
                border: Border.all(color: colors.canvas, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _face(BuildContext context, PlayToneColors palette) {
    final String? url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
            _fallback(palette),
        loadingBuilder: (
          BuildContext _,
          Widget child,
          ImageChunkEvent? progress,
        ) => progress == null ? child : _fallback(palette),
      );
    }
    return _fallback(palette);
  }

  Widget _fallback(PlayToneColors palette) {
    return ColoredBox(
      color: palette.background,
      child: Center(
        child: icon != null
            ? Icon(icon, size: size * 0.5, color: palette.foreground)
            : Text(
                _initial(),
                style: TextStyle(
                  color: palette.foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.4,
                ),
              ),
      ),
    );
  }

  String _initial() {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}

@PlayPreview(name: 'PlayAvatar', size: Size(520, 220))
Widget playAvatarPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              spacing: PlaySpace.lg,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const PlayAvatar(label: 'Ada Lovelace', size: 56),
                const PlayAvatar(label: 'Grace', icon: Icons.person),
                const PlayAvatar(
                  label: 'Alan',
                  tone: PlayTone.mint,
                  dot: true,
                  size: 56,
                ),
                const PlayAvatar(
                  label: 'You',
                  tone: PlayTone.strong,
                  size: 40,
                  ring: true,
                ),
                PlayAvatar(
                  label: 'broken image',
                  imageUrl: 'not-a-url',
                  size: 40,
                  tone: PlayTone.pink,
                ),
              ],
            ),
            const SizedBox(height: PlaySpace.xl),
            Text(
              'monogram falls back safely from a broken image',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        );
      },
    ),
  );
}
