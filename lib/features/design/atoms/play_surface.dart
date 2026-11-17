import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_pressable.dart';

/// The base painted block every other play surface is built from.
///
/// A [PlaySurface] is a rounded rectangle filled with a [PlayTone]. It has no
/// Material `Material`/`Card`/`InkWell` anywhere: the fill, the optional
/// hairline and the shadow are drawn directly, so the look is entirely ours.
class PlaySurface extends StatelessWidget {
  const PlaySurface({
    super.key,
    this.tone = PlayTone.neutral,
    this.radius = PlayRadii.md,
    this.padding,
    this.shadow = PlayShadow.soft,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.onLongPress,
    this.child,
  });

  final PlayTone tone;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final PlayShadow shadow;

  /// Hairline outline width; `0` (the default) draws none.
  final double borderWidth;

  /// Overrides the outline colour (defaults to the tone's border).
  final Color? borderColor;

  /// Overrides the tone's fill (used for subtle states).
  final Color? backgroundColor;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final PlayToneColors tone = colors.tone(this.tone);
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    final Widget painted = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? tone.background,
        borderRadius: borderRadius,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? tone.border ?? colors.line,
                width: borderWidth,
              )
            : null,
        boxShadow: shadow.resolve(colors),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (onTap == null && onLongPress == null) {
      return painted;
    }
    return PlayPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.98,
      child: ClipRRect(borderRadius: borderRadius, child: painted),
    );
  }
}

/// Every tone as a labelled swatch, for eyeballing the palette.
@PlayPreview(name: 'PlaySurface · tones', size: Size(560, 340))
Widget playSurfaceTonesPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Wrap(
          spacing: PlaySpace.sm,
          runSpacing: PlaySpace.sm,
          children: <Widget>[
            for (final PlayTone tone in PlayTone.values)
              PlaySurface(
                tone: tone,
                radius: PlayRadii.sm,
                padding: const EdgeInsets.symmetric(
                  horizontal: PlaySpace.lg,
                  vertical: PlaySpace.md,
                ),
                shadow: PlayShadow.none,
                child: Text(
                  tone.name,
                  style: PlayType.bodyStrong.copyWith(
                    color: colors.tone(tone).foreground,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// The three elevation treatments.
@PlayPreview(name: 'PlaySurface · shadows', size: Size(420, 200))
Widget playSurfaceShadowsPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Wrap(
          spacing: PlaySpace.xl,
          runSpacing: PlaySpace.xl,
          children: <Widget>[
            for (final PlayShadow shadow in PlayShadow.values)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PlaySurface(
                    radius: PlayRadii.md,
                    padding: const EdgeInsets.all(PlaySpace.xl),
                    shadow: shadow,
                    child: const Text(''),
                  ),
                  const SizedBox(height: PlaySpace.sm),
                  Text(
                    shadow.name,
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}
