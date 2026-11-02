import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../domain/entities/review_marker.dart';

/// Draws the map badge for a review cluster: a star, the average rating and how
/// many (friend) reviews the place has — "★ 4.8 · 3 friends".
///
/// Everything is drawn locally with `dart:ui` (no third-party art). Friend-
/// reviewed places get a filled, highlighted badge; other places get a quiet
/// white one, so a friend's review stands out exactly like the reference app's.
class ReviewMarkerComposer {
  /// Composed badge PNGs, keyed by the badge's label + variant.
  final Map<String, Uint8List> _composed = <String, Uint8List>{};

  // --- colours (our own palette) ---
  static const int _teal = 0xFF116B5B;
  static const int _white = 0xFFFFFFFF;
  static const int _ink = 0xFF1B1B1B;
  static const int _amber = 0xFFF9A825;
  static const int _border = 0xFFD9DEE2;

  // --- geometry (logical pixels in the composed PNG) ---
  static const double _height = 52;
  static const double _radius = _height / 2;
  static const double _padH = 18;
  static const double _gap = 8;
  static const double _starSize = 24;

  /// Composes (and caches) the badge for [marker].
  Uint8List? cachedBytes(ReviewMarker marker) => _composed[_cacheKey(marker)];

  Future<Uint8List> compose(ReviewMarker marker) async {
    final String key = _cacheKey(marker);
    final Uint8List? cached = _composed[key];
    if (cached != null) {
      return cached;
    }
    final Uint8List bytes = await _draw(marker);
    _composed[key] = bytes;
    return bytes;
  }

  void dispose() {
    _composed.clear();
  }

  String _cacheKey(ReviewMarker marker) =>
      '${marker.badgeLabel}|${marker.hasFriendReview ? 'friend' : 'public'}';

  Future<Uint8List> _draw(ReviewMarker marker) async {
    final bool friend = marker.hasFriendReview;
    final int background = friend ? _teal : _white;
    final int foreground = friend ? _white : _ink;
    final int starColor = friend ? _white : _amber;

    final TextPainter labelPainter = _text(
      marker.badgeLabel,
      TextStyle(
        color: Color(foreground),
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
    );

    final double content = _starSize + _gap + labelPainter.width;
    final double width = content + _padH * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, _height));

    final ui.RRect pill = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, width, _height),
      const ui.Radius.circular(_radius),
    );
    if (!friend) {
      canvas.drawRRect(
        pill,
        ui.Paint()
          ..color = const Color(_border)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..isAntiAlias = true,
      );
    }
    canvas.drawRRect(
      pill.deflate(friend ? 0 : 1),
      ui.Paint()
        ..color = Color(background)
        ..isAntiAlias = true,
    );

    final double centerY = _height / 2;
    final ui.Path star = _starPath(
      ui.Offset(_padH + _starSize / 2, centerY),
      _starSize / 2,
      _starSize / 2 * 0.45,
    );
    canvas.drawPath(
      star,
      ui.Paint()
        ..color = Color(starColor)
        ..isAntiAlias = true,
    );

    labelPainter.paint(
      canvas,
      ui.Offset(_padH + _starSize + _gap, centerY - labelPainter.height / 2),
    );

    final ui.Picture picture = recorder.endRecording();
    try {
      final ui.Image image = await picture.toImage(
        width.ceil(),
        _height.ceil(),
      );
      try {
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw StateError('Could not encode the review marker image');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  static TextPainter _text(String value, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 320);
  }

  /// A 5-pointed star centred at [center] with outer/inner radii.
  static ui.Path _starPath(ui.Offset center, double outer, double inner) {
    final ui.Path path = ui.Path();
    const int points = 5;
    for (int i = 0; i < points * 2; i++) {
      final double radius = i.isEven ? outer : inner;
      final double angle = -math.pi / 2 + i * math.pi / points;
      final ui.Offset p = ui.Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }
}
