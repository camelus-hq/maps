import 'package:flutter/material.dart';

import '../../../domain/entities/elevation.dart';

/// The route's elevation profile: a distance axis on top, a grade-coloured
/// band (green flat / amber climbing / teal descending) and a marker for the
/// rider's current position. Drawn entirely in code — no assets.
class CycleGradientProfile extends StatelessWidget {
  const CycleGradientProfile({
    super.key,
    required this.profile,
    required this.currentDistanceMeters,
    required this.imperial,
  });

  final ElevationProfile profile;
  final double currentDistanceMeters;
  final bool imperial;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ElevationPoint> points = _smooth(profile.points);
    return CustomPaint(
      size: Size.infinite,
      painter: _GradientPainter(
        points: points,
        totalDistance: points.isEmpty ? 0 : points.last.distanceMeters,
        currentDistanceMeters: currentDistanceMeters,
        imperial: imperial,
        gridColor: scheme.outlineVariant,
        labelColor: scheme.onSurfaceVariant,
        flatColor: const Color(0xFF4C7A2E),
        climbColor: const Color(0xFFB07A2A),
        descentColor: const Color(0xFF2F7D6E),
        markerColor: scheme.primary,
        markerBorder: scheme.surface,
      ),
    );
  }

  /// A small moving average so the (coarse terrain) samples do not paint a
  /// spiky ribbon of alternating ascent/descent bands.
  static List<ElevationPoint> _smooth(List<ElevationPoint> points) {
    if (points.length < 3) {
      return points;
    }
    const int window = 2;
    final List<ElevationPoint> smoothed = <ElevationPoint>[];
    for (int i = 0; i < points.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - window; j <= i + window; j++) {
        if (j < 0 || j >= points.length) {
          continue;
        }
        sum += points[j].elevationMeters;
        count++;
      }
      smoothed.add(
        ElevationPoint(
          distanceMeters: points[i].distanceMeters,
          elevationMeters: sum / count,
        ),
      );
    }
    return smoothed;
  }
}

class _GradientPainter extends CustomPainter {
  _GradientPainter({
    required this.points,
    required this.totalDistance,
    required this.currentDistanceMeters,
    required this.imperial,
    required this.gridColor,
    required this.labelColor,
    required this.flatColor,
    required this.climbColor,
    required this.descentColor,
    required this.markerColor,
    required this.markerBorder,
  });

  final List<ElevationPoint> points;
  final double totalDistance;
  final double currentDistanceMeters;
  final bool imperial;
  final Color gridColor;
  final Color labelColor;
  final Color flatColor;
  final Color climbColor;
  final Color descentColor;
  final Color markerColor;
  final Color markerBorder;

  static const double _topAxis = 18;
  static const double _labelSize = 11;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || totalDistance <= 0 || size.height <= _topAxis) {
      return;
    }
    const double sidePadding = 6;
    final double left = sidePadding;
    final double right = size.width - sidePadding;
    final double trackWidth = right - left;
    if (trackWidth <= 0) {
      return;
    }

    final double minElevation = _min();
    final double maxElevation = _max();
    final double span = (maxElevation - minElevation).clamp(10.0, 100000.0);
    final double chartTop = _topAxis + 6;
    final double chartBottom = size.height - 2;

    double xFor(double distance) =>
        left + (distance / totalDistance).clamp(0.0, 1.0) * trackWidth;
    double yFor(double elevation) {
      final double t = ((elevation - minElevation) / span).clamp(0.0, 1.0);
      return chartBottom - t * (chartBottom - chartTop);
    }

    _paintAxis(canvas, size, left, right, trackWidth);
    _paintGrid(
      canvas,
      left,
      right,
      chartTop,
      chartBottom,
      maxElevation,
      minElevation,
    );

    // The grade-coloured band: one trapezoid per profile segment.
    for (int i = 1; i < points.length; i++) {
      final ElevationPoint a = points[i - 1];
      final ElevationPoint b = points[i];
      final double x0 = xFor(a.distanceMeters);
      final double x1 = xFor(b.distanceMeters);
      if (x1 <= x0) {
        continue;
      }
      final double dSpan = b.distanceMeters - a.distanceMeters;
      final double grade = dSpan <= 0
          ? 0
          : ((b.elevationMeters - a.elevationMeters) / dSpan) * 100;
      final Paint paint = Paint()
        ..color = _gradeColor(grade)
        ..isAntiAlias = false;
      final Path path = Path()
        ..moveTo(x0, yFor(a.elevationMeters))
        ..lineTo(x1, yFor(b.elevationMeters))
        ..lineTo(x1, chartBottom)
        ..lineTo(x0, chartBottom)
        ..close();
      canvas.drawPath(path, paint);
    }

    _paintPosition(
      canvas,
      xFor(currentDistanceMeters),
      chartBottom,
      xFor,
      yFor,
    );
  }

  Color _gradeColor(double grade) {
    if (grade >= 2) {
      return climbColor;
    }
    if (grade <= -2) {
      return descentColor;
    }
    return flatColor;
  }

  void _paintAxis(
    Canvas canvas,
    Size size,
    double left,
    double right,
    double trackWidth,
  ) {
    final Paint tick = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, _topAxis), Offset(right, _topAxis), tick);
    const int ticks = 16;
    for (int i = 0; i <= ticks; i++) {
      final double x = left + trackWidth * i / ticks;
      canvas.drawLine(Offset(x, _topAxis), Offset(x, _topAxis + 3), tick);
    }
    // Labels at 0, ¼, ½, ¾ of the route (matching the reference) — the right
    // edge is the destination flag, so it carries no number.
    for (int i = 0; i < 4; i++) {
      final double fraction = i / 4;
      final String text = i == 0
          ? 'Start'
          : _distanceLabel(totalDistance * fraction);
      final TextPainter painter = _text(text)..layout();
      double x = left + trackWidth * fraction;
      if (i == 0) {
        x = left;
      } else {
        x -= painter.width / 2;
      }
      x = x.clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(x, 0));
    }
  }

  void _paintGrid(
    Canvas canvas,
    double left,
    double right,
    double top,
    double bottom,
    double maxElevation,
    double minElevation,
  ) {
    final Paint dashed = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const double dash = 4;
    const double gap = 4;
    for (final double y in <double>[top, bottom]) {
      for (double x = left; x < right; x += dash + gap) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(left, right), y),
          dashed,
        );
      }
    }
    final TextPainter topLabel = _text('${maxElevation.round()} m')..layout();
    final TextPainter bottomLabel = _text('${minElevation.round()} m')
      ..layout();
    topLabel.paint(canvas, Offset(left + 4, top - topLabel.height - 1));
    bottomLabel.paint(
      canvas,
      Offset(left + 4, bottom - bottomLabel.height - 1),
    );
  }

  void _paintPosition(
    Canvas canvas,
    double x,
    double baseline,
    double Function(double) xFor,
    double Function(double) yFor,
  ) {
    final double y = yFor(_elevationAt(currentDistanceMeters));
    final Offset centre = Offset(x.clamp(xFor(0), xFor(totalDistance)), y);
    canvas.drawCircle(centre, 8, Paint()..color = markerBorder);
    canvas.drawCircle(centre, 6, Paint()..color = markerColor);
  }

  double _elevationAt(double distance) {
    if (distance <= points.first.distanceMeters) {
      return points.first.elevationMeters;
    }
    for (int i = 1; i < points.length; i++) {
      final ElevationPoint a = points[i - 1];
      final ElevationPoint b = points[i];
      if (distance <= b.distanceMeters) {
        final double dSpan = b.distanceMeters - a.distanceMeters;
        final double t = dSpan <= 0
            ? 0
            : ((distance - a.distanceMeters) / dSpan).clamp(0.0, 1.0);
        return a.elevationMeters + (b.elevationMeters - a.elevationMeters) * t;
      }
    }
    return points.last.elevationMeters;
  }

  double _min() {
    double min = points.first.elevationMeters;
    for (final ElevationPoint p in points) {
      if (p.elevationMeters < min) {
        min = p.elevationMeters;
      }
    }
    return min;
  }

  double _max() {
    double max = points.first.elevationMeters;
    for (final ElevationPoint p in points) {
      if (p.elevationMeters > max) {
        max = p.elevationMeters;
      }
    }
    return max;
  }

  String _distanceLabel(double meters) {
    if (imperial) {
      return '${(meters / 1609.344).toStringAsFixed(2)} mi';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  TextPainter _text(String value) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(color: labelColor, fontSize: _labelSize),
    ),
    textDirection: TextDirection.ltr,
  );

  @override
  bool shouldRepaint(_GradientPainter old) =>
      old.points != points ||
      old.currentDistanceMeters != currentDistanceMeters ||
      old.gridColor != gridColor;
}
