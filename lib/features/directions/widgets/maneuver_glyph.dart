import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/route.dart';

/// Our own turn-by-turn maneuver glyph, drawn in code (no Google iconography).
///
/// Original artwork (AGENTS.md §Assets): a stroked arrow/flag per maneuver
/// type, in a 24×24 canvas scaled to [size].
class ManeuverGlyph extends StatelessWidget {
  const ManeuverGlyph({
    super.key,
    required this.type,
    this.size = 24,
    this.color,
  });

  final ManeuverType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ManeuverGlyphPainter(
          type: type,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ManeuverGlyphPainter extends CustomPainter {
  _ManeuverGlyphPainter({required this.type, required this.color});

  final ManeuverType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case ManeuverType.depart:
        canvas.drawCircle(const Offset(12, 12), 4, fill);
      case ManeuverType.arrive:
        _flag(canvas, stroke);
      case ManeuverType.roundabout:
        _roundabout(canvas, stroke);
      case ManeuverType.turnLeft:
        _arrow(canvas, stroke, const <Offset>[
          Offset(16, 20),
          Offset(16, 12),
          Offset(7, 12),
        ]);
      case ManeuverType.turnRight:
        _arrow(canvas, stroke, const <Offset>[
          Offset(8, 20),
          Offset(8, 12),
          Offset(17, 12),
        ]);
      case ManeuverType.merge:
        _merge(canvas, stroke);
      case ManeuverType.straight:
      case ManeuverType.unknown:
        _arrow(canvas, stroke, const <Offset>[Offset(12, 20), Offset(12, 6)]);
    }
    canvas.restore();
  }

  /// A polyline with an arrowhead at the final point (pointing away from the
  /// previous point).
  void _arrow(Canvas canvas, Paint stroke, List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, stroke);
    _head(canvas, stroke, points[points.length - 2], points.last);
  }

  void _head(Canvas canvas, Paint stroke, Offset from, Offset tip) {
    final Offset dir = (tip - from);
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

  void _merge(Canvas canvas, Paint stroke) {
    canvas.drawPath(
      Path()
        ..moveTo(16, 20)
        ..lineTo(12, 12),
      stroke,
    );
    _arrow(canvas, stroke, const <Offset>[
      Offset(12, 20),
      Offset(12, 12),
      Offset(12, 6),
    ]);
  }

  void _roundabout(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(12, 13), 6, stroke);
    _head(canvas, stroke, const Offset(12, 19), const Offset(12, 6));
  }

  void _flag(Canvas canvas, Paint stroke) {
    canvas.drawLine(const Offset(7, 20), const Offset(7, 4), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(7, 4)
        ..lineTo(18, 7)
        ..lineTo(7, 11),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_ManeuverGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
