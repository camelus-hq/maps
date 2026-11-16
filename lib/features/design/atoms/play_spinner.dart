import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../play_previews.dart';

/// A spinning arc loader — the play replacement for `CircularProgressIndicator`.
///
/// Note: like Material's spinner it animates continuously, so a widget test
/// that shows it must `pump` a fixed duration rather than `pumpAndSettle`.
class PlaySpinner extends StatefulWidget {
  const PlaySpinner({
    super.key,
    this.size = 28,
    this.strokeWidth = 3,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<PlaySpinner> createState() => _PlaySpinnerState();
}

class _PlaySpinnerState extends State<PlaySpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? PlayColors.of(context).primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _ArcPainter(color: color, strokeWidth: widget.strokeWidth),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final Rect rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      math.pi * 1.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

@PlayPreview(name: 'PlaySpinner', size: Size(240, 160))
Widget playSpinnerPreview() =>
    const PlayPreviewFrame(child: PlaySpinner(size: 40));
