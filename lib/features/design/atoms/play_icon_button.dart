import 'dart:math' as math;

import 'package:flutter/widgets.dart';
// Only the preview glyphs come from Material; the atom takes an [IconData].
import 'package:material_ui/material_ui.dart' show Icons;

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_surface.dart';

/// Visual treatments for [PlayIconButton].
enum PlayIconButtonVariant {
  /// Card-white circle with a hairline (the default floating map control).
  surface,

  /// Solid brand blue.
  primary,

  /// No fill — just the glyph on whatever is behind it.
  plain,
}

/// A round, press-squashing icon control — the play replacement for the
/// floating map controls.
///
/// [active] and [alert] override the variant so "on" and "problem" states read
/// the same on a white circle or a coloured one.
class PlayIconButton extends StatelessWidget {
  const PlayIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = PlayIconButtonVariant.surface,
    this.tone,
    this.size = 48,
    this.iconSize,
    this.active = false,
    this.alert = false,
    this.rotation = 0,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final PlayIconButtonVariant variant;

  /// Overrides the variant's fill with a palette tone.
  final PlayTone? tone;
  final double size;
  final double? iconSize;

  /// Toggled-on treatment (solid brand blue).
  final bool active;

  /// Problem treatment (coral).
  final bool alert;

  /// Rotates the glyph, in radians (e.g. a compass needle).
  final double rotation;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors palette = _palette(colors);
    final bool enabled = onPressed != null;
    final Widget glyph = rotation == 0
        ? Icon(icon, size: iconSize ?? size * 0.5, color: palette.foreground)
        : Transform.rotate(
            angle: rotation,
            child: Icon(
              icon,
              size: iconSize ?? size * 0.5,
              color: palette.foreground,
            ),
          );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: PlaySurface(
        radius: PlayRadii.pill,
        shadow: variant == PlayIconButtonVariant.plain
            ? PlayShadow.none
            : PlayShadow.soft,
        borderWidth: variant == PlayIconButtonVariant.surface ? 1 : 0,
        backgroundColor: palette.background,
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: semanticLabel == null
                ? glyph
                : Semantics(label: semanticLabel, child: glyph),
          ),
        ),
      ),
    );
  }

  PlayToneColors _palette(PlayColors colors) {
    if (alert) {
      return colors.tone(PlayTone.coral);
    }
    if (active) {
      return colors.tone(PlayTone.primary);
    }
    final PlayTone? explicit = tone;
    if (explicit != null) {
      return colors.tone(explicit);
    }
    return switch (variant) {
      PlayIconButtonVariant.surface => colors.tone(PlayTone.neutral),
      PlayIconButtonVariant.primary => colors.tone(PlayTone.primary),
      PlayIconButtonVariant.plain => PlayToneColors(
        background: const Color(0x00000000),
        foreground: colors.ink,
      ),
    };
  }
}

@PlayPreview(name: 'PlayIconButton', size: Size(520, 260))
Widget playIconButtonPreview() {
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const PlayIconButton(
                  icon: Icons.layers_outlined,
                  semanticLabel: 'Layers',
                ),
                const PlayIconButton(
                  icon: Icons.my_location,
                  variant: PlayIconButtonVariant.primary,
                ),
                const PlayIconButton(
                  icon: Icons.navigation_outlined,
                  variant: PlayIconButtonVariant.plain,
                ),
                PlayIconButton(
                  icon: Icons.navigation_outlined,
                  variant: PlayIconButtonVariant.plain,
                  rotation: math.pi * 0.25,
                ),
                const PlayIconButton(icon: Icons.my_location, active: true),
                const PlayIconButton(icon: Icons.gps_off, alert: true),
                PlayIconButton(icon: Icons.place, tone: PlayTone.mint),
                const PlayIconButton(icon: Icons.add, size: 64),
              ],
            ),
            const SizedBox(height: PlaySpace.xl),
            Text(
              'one tab = one circle • press to squash',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        );
      },
    ),
  );
}
