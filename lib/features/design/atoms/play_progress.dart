import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';

/// A slim progress bar — the play replacement for Material's
/// `LinearProgressIndicator`.
///
/// A `null` [value] draws an empty track (no indeterminate animation, so a
/// widget test can `pumpAndSettle`).
class PlayProgress extends StatelessWidget {
  const PlayProgress({super.key, this.value, this.height = 6, this.tone});

  /// `0..1`, or `null` for an empty track.
  final double? value;
  final double height;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final double? progress = value;
    final double fraction = progress == null ? 0 : progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(PlayRadii.pill),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: colors.surfaceSunken),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: ColoredBox(color: tone ?? colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayProgress', size: Size(420, 140))
Widget playProgressPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PlayProgress(value: 0.35),
            const SizedBox(height: PlaySpace.lg),
            const PlayProgress(value: 0.8),
            const SizedBox(height: PlaySpace.lg),
            PlayProgress(value: 0.55, tone: colors.mint),
          ],
        );
      },
    ),
  );
}
