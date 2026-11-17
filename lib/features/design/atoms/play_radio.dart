import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';

/// A radio indicator for a [PlayRow] — the play replacement for Material's
/// `Radio`.
///
/// Non-interactive on its own: the surrounding row owns the tap.
class PlayRadio extends StatelessWidget {
  const PlayRadio({super.key, required this.selected, this.size = 22});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.primary : colors.line,
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: selected ? size * 0.46 : 0,
          height: selected ? size * 0.46 : 0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayRadio', size: Size(260, 140))
Widget playRadioPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PlayRadio(selected: true),
            const SizedBox(width: PlaySpace.xl),
            const PlayRadio(selected: false),
            const SizedBox(width: PlaySpace.xl),
            Text(
              'selected · unselected',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        );
      },
    ),
  );
}
