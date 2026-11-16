import 'package:flutter/widgets.dart';
// Only the preview glyphs come from Material; the atoms themselves are
// Material-agnostic (they take an [IconData]).
import 'package:material_ui/material_ui.dart' show Icons;

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_surface.dart';

/// Visual treatments for [PlayButton].
enum PlayButtonVariant {
  /// Brand blue, the main call to action.
  primary,

  /// Inverted high-contrast block.
  strong,

  /// A soft blue wash of the brand colour.
  soft,

  /// Transparent with a hairline outline.
  ghost,
}

/// Sizes for [PlayButton].
enum PlayButtonSize { sm, md, lg }

/// The play call-to-action: a full pill that squashes on press.
///
/// Built on [PlaySurface], so it has none of Material's elevation/ink/state
/// machinery — colour, radius and press feedback are ours.
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PlayButtonVariant.primary,
    this.size = PlayButtonSize.md,
    this.tone,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PlayButtonVariant variant;
  final PlayButtonSize size;

  /// Overrides the variant's colours with an explicit palette tone.
  final PlayTone? tone;

  /// Stretches to the parent's width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = _palette(colors);
    final _ButtonMetrics metrics = _ButtonMetrics.of(size);
    final bool enabled = onPressed != null;

    Widget row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: metrics.iconSize, color: palette.foreground),
          const SizedBox(width: PlaySpace.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: metrics.fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: palette.foreground,
            ),
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: PlaySpace.sm),
          Icon(trailingIcon, size: metrics.iconSize, color: palette.foreground),
        ],
      ],
    );

    if (expand) {
      row = SizedBox(width: double.infinity, child: row);
    }

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: PlaySurface(
        radius: PlayRadii.pill,
        padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
        shadow: variant == PlayButtonVariant.ghost
            ? PlayShadow.none
            : PlayShadow.soft,
        borderWidth: variant == PlayButtonVariant.ghost ? 1.5 : 0,
        backgroundColor: palette.background,
        onTap: onPressed,
        child: SizedBox(height: metrics.height, child: row),
      ),
    );
  }

  PlayToneColors _palette(PlayColors colors) {
    final PlayTone? explicit = tone;
    if (explicit != null) {
      return colors.tone(explicit);
    }
    return switch (variant) {
      PlayButtonVariant.primary => colors.tone(PlayTone.primary),
      PlayButtonVariant.strong => colors.tone(PlayTone.strong),
      PlayButtonVariant.soft => colors.tone(PlayTone.soft),
      PlayButtonVariant.ghost => PlayToneColors(
        background: const Color(0x00000000),
        foreground: colors.ink,
      ),
    };
  }
}

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.height,
    required this.horizontalPadding,
    required this.fontSize,
    required this.iconSize,
  });

  final double height;
  final double horizontalPadding;
  final double fontSize;
  final double iconSize;

  static _ButtonMetrics of(PlayButtonSize size) => switch (size) {
    PlayButtonSize.sm => const _ButtonMetrics(
      height: 38,
      horizontalPadding: PlaySpace.lg,
      fontSize: 13.5,
      iconSize: 16,
    ),
    PlayButtonSize.md => const _ButtonMetrics(
      height: 46,
      horizontalPadding: PlaySpace.xl,
      fontSize: 15,
      iconSize: 18,
    ),
    PlayButtonSize.lg => const _ButtonMetrics(
      height: 56,
      horizontalPadding: PlaySpace.xxl,
      fontSize: 16,
      iconSize: 20,
    ),
  };
}

@PlayPreview(name: 'PlayButton · variants', size: Size(520, 340))
Widget playButtonPreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topCenter,
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: PlaySpace.sm,
              runSpacing: PlaySpace.sm,
              children: <Widget>[
                for (final PlayButtonVariant variant
                    in PlayButtonVariant.values)
                  PlayButton(
                    label: variant.name,
                    icon: Icons.arrow_forward,
                    variant: variant,
                    onPressed: () {},
                  ),
              ],
            ),
            const SizedBox(height: PlaySpace.xl),
            Text(
              'sizes',
              style: PlayType.overline.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: PlaySpace.sm),
            Wrap(
              spacing: PlaySpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final PlayButtonSize size in PlayButtonSize.values)
                  PlayButton(
                    label: size.name,
                    size: size,
                    tone: PlayTone.mint,
                    onPressed: () {},
                  ),
                const PlayButton(label: 'disabled', icon: Icons.lock_outline),
              ],
            ),
          ],
        );
      },
    ),
  );
}
