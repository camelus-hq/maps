import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Draws our own teardrop map pin (no third-party icon assets) and returns it as
/// PNG bytes for the Mapbox point-annotation manager.
///
/// The pin is anchored at its tip (`IconAnchor.BOTTOM`) so the point of the drop
/// sits exactly on the coordinate. A subtle soft shadow and a white outline keep
/// it legible over any basemap.
Future<Uint8List> buildOriginalMarkerImage({required int argb}) {
  return _encodePin(argb: argb, star: false);
}

/// Draws our own "saved place" pin (same teardrop, with a white star inside).
Future<Uint8List> buildOriginalStarMarkerImage({required int argb}) {
  return _encodePin(argb: argb, star: true);
}

/// Draws our own translucent "device heading" cone (no third-party art) and
/// returns it as PNG bytes for the Mapbox location puck's `bearingImage`.
///
/// The cone's apex sits at the image centre and it opens upward, so when the
/// puck rotates it to the device heading the point stays on the location and
/// the wedge points the way the phone is facing (mirroring Google Maps'
/// heading beam with our own colours).
Future<Uint8List> buildOriginalHeadingConeImage({required int argb}) {
  return _encodeHeadingCone(argb: argb);
}

/// Canvas size of a pin image. The tip is at the bottom centre; the head is a
/// circle above it.
const double _pinWidth = 72;
const double _pinHeight = 96;
const ui.Offset _pinHead = ui.Offset(_pinWidth / 2, 34);
const double _pinRadius = 26;
const double _pinTipY = 92;

Future<Uint8List> _encodePin({required int argb, required bool star}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.clipRect(ui.Rect.fromLTRB(0, 0, _pinWidth, _pinHeight));

  // Soft drop shadow sitting under the tip.
  canvas.drawOval(
    ui.Rect.fromCenter(
      center: const ui.Offset(_pinWidth / 2, _pinTipY),
      width: 32,
      height: 11,
    ),
    ui.Paint()
      ..color = const ui.Color(0x33000000)
      ..isAntiAlias = true,
  );

  final ui.Path pin = _pinPath();
  // White outline first: the coloured body below covers its inner half.
  canvas.drawPath(
    pin,
    ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 7
      ..isAntiAlias = true,
  );
  canvas.drawPath(
    pin,
    ui.Paint()
      ..color = ui.Color(argb)
      ..isAntiAlias = true,
  );

  // Inner disc holding a dot (result pin) or a star (saved pin).
  canvas.drawCircle(
    _pinHead,
    _pinRadius * 0.6,
    ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..isAntiAlias = true,
  );
  if (star) {
    canvas.drawPath(
      _starPath(_pinHead, _pinRadius * 0.44, _pinRadius * 0.18),
      ui.Paint()
        ..color = ui.Color(argb)
        ..isAntiAlias = true,
    );
  } else {
    canvas.drawCircle(
      _pinHead,
      _pinRadius * 0.29,
      ui.Paint()
        ..color = ui.Color(argb)
        ..isAntiAlias = true,
    );
  }

  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(
      _pinWidth.toInt(),
      _pinHeight.toInt(),
    );
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data == null) {
        throw StateError('Could not encode the marker image');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

const double _coneSize = 160;
const ui.Offset _coneApex = ui.Offset(_coneSize / 2, _coneSize / 2);
const double _coneRadius = 70;
const double _coneHalfAngle = 32 * math.pi / 180;

Future<Uint8List> _encodeHeadingCone({required int argb}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.clipRect(ui.Rect.fromLTRB(0, 0, _coneSize, _coneSize));

  const double up = -math.pi / 2;
  final ui.Offset left = ui.Offset(
    _coneApex.dx + _coneRadius * math.cos(up - _coneHalfAngle),
    _coneApex.dy + _coneRadius * math.sin(up - _coneHalfAngle),
  );
  final ui.Path wedge = ui.Path()
    ..moveTo(_coneApex.dx, _coneApex.dy)
    ..lineTo(left.dx, left.dy)
    ..arcTo(
      ui.Rect.fromCircle(center: _coneApex, radius: _coneRadius),
      up - _coneHalfAngle,
      _coneHalfAngle * 2,
      false,
    )
    ..close();

  // Soft fade from the apex outward so the beam reads as a glow, not a hard
  // triangle (our own look, not a copy of anyone's artwork).
  final ui.Paint paint = ui.Paint()
    ..isAntiAlias = true
    ..shader = ui.Gradient.radial(
      _coneApex,
      _coneRadius,
      <ui.Color>[
        ui.Color(argb).withValues(alpha: 0.7),
        ui.Color(argb).withValues(alpha: 0.28),
        ui.Color(argb).withValues(alpha: 0),
      ],
      <double>[0, 0.55, 1],
    );
  canvas.drawPath(wedge, paint);

  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(
      _coneSize.toInt(),
      _coneSize.toInt(),
    );
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data == null) {
        throw StateError('Could not encode the heading cone image');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// A classic map-pin silhouette: a round head with a tail meeting a point at
/// the bottom centre.
ui.Path _pinPath() {
  const double deg = math.pi / 180;
  const double startAngle = 140 * deg;
  const double sweepAngle = 260 * deg;
  final ui.Offset left = ui.Offset(
    _pinHead.dx + _pinRadius * math.cos(startAngle),
    _pinHead.dy + _pinRadius * math.sin(startAngle),
  );
  final ui.Offset right = ui.Offset(
    _pinHead.dx + _pinRadius * math.cos(startAngle + sweepAngle),
    _pinHead.dy + _pinRadius * math.sin(startAngle + sweepAngle),
  );
  final ui.Path path = ui.Path()
    ..moveTo(_pinHead.dx, _pinTipY)
    ..quadraticBezierTo(
      _pinHead.dx - _pinRadius * 0.95,
      _pinHead.dy + _pinRadius * 1.05,
      left.dx,
      left.dy,
    )
    ..arcTo(
      ui.Rect.fromCircle(center: _pinHead, radius: _pinRadius),
      startAngle,
      sweepAngle,
      false,
    )
    ..quadraticBezierTo(right.dx, right.dy, _pinHead.dx, _pinTipY)
    ..close();
  return path;
}

/// Builds a 5-pointed star centred at [center] with outer/inner radii.
ui.Path _starPath(ui.Offset center, double outer, double inner) {
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
