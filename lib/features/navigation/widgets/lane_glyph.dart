import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/route.dart';

/// Our own lane-arrow glyph (drawn in code, 24×24 canvas scaled to [size]).
///
/// Original artwork (AGENTS.md §Assets) — no Google iconography. Used by the
/// lane-guidance strip.
class LaneGlyph extends StatelessWidget {
  const LaneGlyph({
    super.key,
    required this.indication,
    this.size = 22,
    this.color,
  });

  final LaneIndication indication;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LaneGlyphPainter(
          indication: indication,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _LaneGlyphPainter extends CustomPainter {
  _LaneGlyphPainter({required this.indication, required this.color});

  final LaneIndication indication;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (indication) {
      case LaneIndication.straight:
        _arrow(canvas, stroke, const <Offset>[Offset(12, 20), Offset(12, 5)]);
      case LaneIndication.left:
        _arrow(canvas, stroke, const <Offset>[
          Offset(17, 20),
          Offset(17, 12),
          Offset(6, 12),
        ]);
      case LaneIndication.slightLeft:
        _arrow(canvas, stroke, const <Offset>[
          Offset(15, 20),
          Offset(15, 13),
          Offset(8, 7),
        ]);
      case LaneIndication.sharpLeft:
        _arrow(canvas, stroke, const <Offset>[
          Offset(17, 20),
          Offset(17, 14),
          Offset(11, 14),
          Offset(11, 6),
        ]);
      case LaneIndication.right:
        _arrow(canvas, stroke, const <Offset>[
          Offset(7, 20),
          Offset(7, 12),
          Offset(18, 12),
        ]);
      case LaneIndication.slightRight:
        _arrow(canvas, stroke, const <Offset>[
          Offset(9, 20),
          Offset(9, 13),
          Offset(16, 7),
        ]);
      case LaneIndication.sharpRight:
        _arrow(canvas, stroke, const <Offset>[
          Offset(7, 20),
          Offset(7, 14),
          Offset(13, 14),
          Offset(13, 6),
        ]);
      case LaneIndication.uTurn:
      case LaneIndication.reverse:
        _uTurn(canvas, stroke);
      case LaneIndication.merge:
      case LaneIndication.mergeRight:
        _merge(canvas, stroke, left: false);
      case LaneIndication.mergeLeft:
        _merge(canvas, stroke, left: true);
      case LaneIndication.forkLeft:
        _arrow(canvas, stroke, const <Offset>[
          Offset(15, 20),
          Offset(15, 12),
          Offset(7, 7),
        ]);
      case LaneIndication.forkRight:
        _arrow(canvas, stroke, const <Offset>[
          Offset(9, 20),
          Offset(9, 12),
          Offset(17, 7),
        ]);
      case LaneIndication.unknown:
        _arrow(canvas, stroke, const <Offset>[Offset(12, 20), Offset(12, 5)]);
    }
    canvas.restore();
  }

  void _arrow(Canvas canvas, Paint stroke, List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, stroke);
    _head(canvas, stroke, points[points.length - 2], points.last);
  }

  void _head(Canvas canvas, Paint stroke, Offset from, Offset tip) {
    final Offset dir = tip - from;
    final double angle = math.atan2(dir.dy, dir.dx);
    const double headLength = 5;
    const double spread = 0.6;
    final Offset a =
        tip -
        Offset(math.cos(angle - spread), math.sin(angle - spread)) * headLength;
    final Offset b =
        tip -
        Offset(math.cos(angle + spread), math.sin(angle + spread)) * headLength;
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(b.dx, b.dy),
      stroke,
    );
  }

  void _uTurn(Canvas canvas, Paint stroke) {
    canvas.drawPath(
      Path()
        ..moveTo(15, 20)
        ..lineTo(15, 11)
        ..arcToPoint(
          const Offset(9, 11),
          radius: const Radius.circular(3),
          clockwise: true,
        )
        ..lineTo(9, 20),
      stroke,
    );
    _head(canvas, stroke, const Offset(9, 14), const Offset(9, 21));
  }

  void _merge(Canvas canvas, Paint stroke, {required bool left}) {
    final double from = left ? 8 : 16;
    final double startX = left ? 13 : 11;
    canvas.drawPath(
      Path()
        ..moveTo(from, 20)
        ..lineTo(12, 13),
      stroke,
    );
    _arrow(canvas, stroke, <Offset>[
      Offset(startX, 20),
      Offset(12, 12),
      Offset(12, 5),
    ]);
  }

  @override
  bool shouldRepaint(_LaneGlyphPainter oldDelegate) =>
      oldDelegate.indication != indication || oldDelegate.color != color;
}
