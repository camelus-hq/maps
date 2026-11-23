import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../../../domain/entities/lat_lon.dart';

/// A lightweight preview of a trip's recorded track.
///
/// Deliberately **not** the live Mapbox surface: a pushed page cannot share the
/// map-home platform view, so the recorded breadcrumb is projected onto a plain
/// canvas with our own colours — no map imagery, no Google styling. The shape is
/// aspect-correct (metres, not degrees), so a north-south ride does not look
/// squashed.
class TripTrackPreview extends StatelessWidget {
  const TripTrackPreview({super.key, required this.track, this.height = 200});

  final List<LatLon> track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(PlayRadii.md),
      child: ColoredBox(
        color: colors.surfaceSunken,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrackPainter(
              track: track,
              line: colors.primary,
              start: colors.teal,
              end: colors.coral,
              grid: colors.line,
              marker: colors.surface,
              empty: colors.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.track,
    required this.line,
    required this.start,
    required this.end,
    required this.grid,
    required this.marker,
    required this.empty,
  });

  final List<LatLon> track;
  final Color line;
  final Color start;
  final Color end;
  final Color grid;
  final Color marker;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    _paintGrid(canvas, size);
    if (track.isEmpty) {
      _paintDot(canvas, Offset(size.width / 2, size.height / 2), empty);
      return;
    }

    final double minLat = _min(track, (LatLon p) => p.latitude);
    final double maxLat = _max(track, (LatLon p) => p.latitude);
    final double minLon = _min(track, (LatLon p) => p.longitude);
    final double maxLon = _max(track, (LatLon p) => p.longitude);
    const double pad = 26;
    final double width = math.max(1, size.width - pad * 2);
    final double height = math.max(1, size.height - pad * 2);
    final double midLat = (minLat + maxLat) / 2;
    final double metersPerLon =
        111320 * math.cos(midLat * math.pi / 180).abs().clamp(0.05, 1.0);
    final double spanX = (maxLon - minLon) * metersPerLon;
    final double spanY = (maxLat - minLat) * 111320;
    // Fit the real-world extents into the canvas, centred, preserving shape.
    final double scale = math.min(
      width / (spanX <= 0 ? 1 : spanX),
      height / (spanY <= 0 ? 1 : spanY),
    );
    final double drawWidth = spanX * scale;
    final double drawHeight = spanY * scale;
    final double originX = (size.width - drawWidth) / 2;
    final double originY = (size.height - drawHeight) / 2;
    Offset project(LatLon point) => Offset(
      originX + (point.longitude - minLon) * metersPerLon * scale,
      originY + (maxLat - point.latitude) * 111320 * scale,
    );

    if (track.length >= 2) {
      final Path path = Path()
        ..moveTo(project(track.first).dx, project(track.first).dy);
      for (int i = 1; i < track.length; i++) {
        final Offset point = project(track[i]);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    _paintDot(canvas, project(track.first), start);
    if (track.length >= 2) {
      _paintDot(canvas, project(track.last), end);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const double step = 32;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 6, Paint()..color = marker);
    canvas.drawCircle(center, 4.5, Paint()..color = color);
  }

  static double _min(List<LatLon> points, double Function(LatLon) value) {
    double result = value(points.first);
    for (final LatLon point in points) {
      result = math.min(result, value(point));
    }
    return result;
  }

  static double _max(List<LatLon> points, double Function(LatLon) value) {
    double result = value(points.first);
    for (final LatLon point in points) {
      result = math.max(result, value(point));
    }
    return result;
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      !identical(oldDelegate.track, track);
}
