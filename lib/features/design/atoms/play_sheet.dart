import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';

/// The play sheet surface: a rounded-top block that hosts a sheet's content.
///
/// Deliberately just the surface — the scrollable (and therefore the drag that
/// moves a [DraggableScrollableSheet]) must be the caller's child, so the grab
/// handle stays the first item *inside* that scrollable. Pair it with
/// [PlaySheetHandle].
class PlaySheet extends StatelessWidget {
  const PlaySheet({
    super.key,
    this.tone = PlayTone.neutral,
    this.radius = PlayRadii.lg,
    this.child,
  });

  final PlayTone tone;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final BorderRadius borderRadius = BorderRadius.vertical(
      top: Radius.circular(radius),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tone(tone).background,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

/// The grab handle at the top of a sheet.
///
/// When it is the first child of a `DraggableScrollableSheet`'s scroll view it
/// also drags the sheet; in a modal it sits above the content.
class PlaySheetHandle extends StatelessWidget {
  const PlaySheetHandle({
    super.key,
    this.color,
    this.width = 40,
    this.height = 4,
  });

  final Color? color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PlaySpace.md),
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color ?? colors.inkFaint,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlaySheet', size: Size(360, 320))
Widget playSheetPreview() {
  return PlayPreviewFrame(
    child: PlaySheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PlaySheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.lg,
              0,
              PlaySpace.lg,
              PlaySpace.xl,
            ),
            child: Builder(
              builder: (BuildContext context) => Text(
                'Sheet content sits inside the rounded surface.',
                style: PlayType.body.copyWith(
                  color: PlayColors.of(context).ink,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
