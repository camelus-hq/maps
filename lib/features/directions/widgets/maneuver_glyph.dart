import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/route.dart';

/// Our own turn-by-turn maneuver glyph, drawn in code (no Google iconography).
///
/// Original artwork (AGENTS.md §Assets): a stroked arrow/flag per maneuver
/// type, in a 24×24 canvas scaled to [size]. Every [ManeuverType] gets its own
/// shape — slight/regular/sharp, U-turn, keep/ramp/exit/merge and both
/// roundabout directions are not collapsed into a plain left/right.
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
      case ManeuverType.roundaboutExit:
        _roundaboutExit(canvas, stroke);
      case ManeuverType.straight:
      case ManeuverType.unknown:
        _arrow(canvas, stroke, const <Offset>[Offset(12, 20), Offset(12, 6)]);
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
      case ManeuverType.slightLeft:
        _arrow(canvas, stroke, const <Offset>[
          Offset(15, 20),
          Offset(15, 13),
          Offset(8, 7),
        ]);
      case ManeuverType.slightRight:
        _arrow(canvas, stroke, const <Offset>[
          Offset(9, 20),
          Offset(9, 13),
          Offset(16, 7),
        ]);
      case ManeuverType.sharpLeft:
        _arrow(canvas, stroke, const <Offset>[
          Offset(17, 20),
          Offset(17, 14),
          Offset(11, 14),
          Offset(11, 6),
        ]);
      case ManeuverType.sharpRight:
        _arrow(canvas, stroke, const <Offset>[
          Offset(7, 20),
          Offset(7, 14),
          Offset(13, 14),
          Offset(13, 6),
        ]);
      case ManeuverType.uTurnLeft:
        _uTurn(canvas, stroke, left: true);
      case ManeuverType.uTurnRight:
        _uTurn(canvas, stroke, left: false);
      case ManeuverType.keepLeft:
        _keep(canvas, stroke, left: true);
      case ManeuverType.keepRight:
        _keep(canvas, stroke, left: false);
      case ManeuverType.rampLeft:
        _ramp(canvas, stroke, left: true);
      case ManeuverType.rampRight:
        _ramp(canvas, stroke, left: false);
      case ManeuverType.exitLeft:
        _exit(canvas, stroke, left: true);
      case ManeuverType.exitRight:
        _exit(canvas, stroke, left: false);
      case ManeuverType.merge:
      case ManeuverType.mergeRight:
        _merge(canvas, stroke, left: false);
      case ManeuverType.mergeLeft:
        _merge(canvas, stroke, left: true);
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

  /// A U-turn whose return leg runs on the [left] or right.
  void _uTurn(Canvas canvas, Paint stroke, {required bool left}) {
    final double near = left ? 16 : 8;
    final double far = left ? 8 : 16;
    canvas.drawPath(
      Path()
        ..moveTo(near, 20)
        ..lineTo(near, 11)
        ..cubicTo(near, 6.5, far, 6.5, far, 11)
        ..lineTo(far, 20),
      stroke,
    );
    _head(canvas, stroke, Offset(far, 13), Offset(far, 20));
  }

  /// "Keep left/right": a through arrow with a branch peeling off to the side.
  void _keep(Canvas canvas, Paint stroke, {required bool left}) {
    final double x = left ? 13.5 : 10.5;
    final double branchX = left ? 5.5 : 18.5;
    _arrow(canvas, stroke, <Offset>[Offset(x, 20), Offset(x, 5)]);
    canvas.drawPath(
      Path()
        ..moveTo(x, 14)
        ..lineTo(branchX, 9),
      stroke,
    );
    _head(canvas, stroke, Offset(x, 14), Offset(branchX, 9));
  }

  /// A ramp diverging to the side while the road continues straight.
  void _ramp(Canvas canvas, Paint stroke, {required bool left}) {
    final double dir = left ? -1 : 1;
    canvas.drawPath(
      Path()
        ..moveTo(12 - dir * 5, 20)
        ..lineTo(12 - dir * 5, 9),
      stroke,
    );
    _arrow(canvas, stroke, <Offset>[
      Offset(12, 20),
      Offset(12, 12),
      Offset(12 + dir * 7, 5),
    ]);
  }

  /// An exit diverging sharply to the side (a steeper ramp).
  void _exit(Canvas canvas, Paint stroke, {required bool left}) {
    final double dir = left ? -1 : 1;
    canvas.drawPath(
      Path()
        ..moveTo(12 - dir * 5, 20)
        ..lineTo(12 - dir * 5, 11),
      stroke,
    );
    _arrow(canvas, stroke, <Offset>[
      Offset(10, 20),
      Offset(12, 14),
      Offset(12 + dir * 8, 4),
    ]);
  }

  void _merge(Canvas canvas, Paint stroke, {required bool left}) {
    final double from = left ? 8 : 16;
    canvas.drawPath(
      Path()
        ..moveTo(from, 20)
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

  void _roundaboutExit(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(10, 14), 5.5, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(13, 10)
        ..lineTo(19, 5),
      stroke,
    );
    _head(canvas, stroke, const Offset(13, 10), const Offset(19, 5));
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
