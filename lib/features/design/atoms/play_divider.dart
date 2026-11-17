import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';

/// A hairline rule, optionally dotted.
///
/// The dotted mode is a small hand-drawn-feeling signature that a Material
/// `Divider` cannot express.
class PlayDivider extends StatelessWidget {
  const PlayDivider({
    super.key,
    this.dotted = false,
    this.color,
    this.thickness = 1,
  });

  final bool dotted;
  final Color? color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final Color line = color ?? colors.line;
    if (!dotted) {
      return SizedBox(
        height: thickness,
        width: double.infinity,
        child: ColoredBox(color: line),
      );
    }
    return SizedBox(
      height: thickness * 2,
      width: double.infinity,
      child: CustomPaint(
        painter: _DottedPainter(color: line, radius: thickness),
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  const _DottedPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double step = radius * 3.2;
    for (double x = radius; x < size.width; x += step) {
      canvas.drawCircle(Offset(x, size.height / 2), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

@PlayPreview(name: 'PlayDivider', size: Size(420, 160))
Widget playDividerPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PlayDivider(),
            const SizedBox(height: PlaySpace.xl),
            const PlayDivider(dotted: true),
            const SizedBox(height: PlaySpace.xl),
            PlayDivider(dotted: true, color: colors.ink, thickness: 2),
          ],
        );
      },
    ),
  );
}
