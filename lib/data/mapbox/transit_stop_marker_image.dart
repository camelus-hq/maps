import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../domain/entities/transit_stop_marker.dart';

/// Draws the transit stop circle for the map: a white centre inside a ring in
/// the line's colour, larger where the traveller boards or leaves a vehicle.
///
/// Everything is drawn locally with `dart:ui` (no third-party art) and cached
/// per (size, colour), so a journey with many stops only composes a handful of
/// images.
class TransitStopMarkerComposer {
  final Map<String, Uint8List> _composed = <String, Uint8List>{};

  /// Circle diameter (logical px) for a pass-through stop / a board-alight stop.
  static const double passDiameter = 16;
  static const double boardDiameter = 26;

  /// Ring thickness in logical px.
  static const double passRing = 4;
  static const double boardRing = 5;

  /// Room around the circle for the soft shadow / white halo.
  static const double _pad = 4;

  static const int _defaultColor = 0xFF116B5B;
  static const int _white = 0xFFFFFFFF;

  /// The full image size (circle + [pad]) for [emphasis]; the map layer draws it
  /// at `iconSize: 1`, so these are logical pixels.
  static double imageSize(TransitStopEmphasis emphasis) =>
      (emphasis == TransitStopEmphasis.board ? boardDiameter : passDiameter) +
      _pad * 2;

  Uint8List? cachedBytes(TransitStopMarker marker) => _composed[_key(marker)];

  Future<Uint8List> compose(TransitStopMarker marker) async {
    final String key = _key(marker);
    final Uint8List? cached = _composed[key];
    if (cached != null) {
      return cached;
    }
    final Uint8List bytes = await _draw(marker);
    _composed[key] = bytes;
    return bytes;
  }

  void dispose() => _composed.clear();

  static String _key(TransitStopMarker marker) =>
      '${marker.emphasis.name}|${(marker.color ?? _defaultColor).toRadixString(16)}';

  Future<Uint8List> _draw(TransitStopMarker marker) async {
    final bool board = marker.isBoard;
    final double diameter = board ? boardDiameter : passDiameter;
    final double radius = diameter / 2;
    final double ring = board ? boardRing : passRing;
    final int color = marker.color ?? _defaultColor;
    final double size = diameter + _pad * 2;
    final ui.Offset center = ui.Offset(size / 2, size / 2);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.clipRect(ui.Rect.fromLTWH(0, 0, size, size));

    // Soft shadow so the circle stays legible over any basemap.
    canvas.drawCircle(
      ui.Offset(center.dx, center.dy + 1),
      radius,
      ui.Paint()
        ..color = const ui.Color(0x33000000)
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5),
    );
    // White halo, then the coloured disc, then the white centre: the visible
    // ring is exactly [ring] px wide.
    canvas.drawCircle(
      center,
      radius + 1,
      ui.Paint()
        ..color = const ui.Color(_white)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()
        ..color = ui.Color(color)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      center,
      radius - ring,
      ui.Paint()
        ..color = const ui.Color(_white)
        ..isAntiAlias = true,
    );

    final ui.Picture picture = recorder.endRecording();
    try {
      final ui.Image image = await picture.toImage(size.ceil(), size.ceil());
      try {
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw StateError('Could not encode the transit stop image');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
