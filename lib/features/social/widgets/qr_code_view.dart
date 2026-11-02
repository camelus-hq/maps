import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Draws a QR code for [data] with the `qr` encoder and our own painter.
///
/// The `qr` package only produces the module matrix (no Flutter widget), so the
/// squares are painted here: a light background with a quiet zone, then one
/// square per dark module. Nothing is loaded from an asset or a third-party
/// image — the code is generated locally from the user's own npub.
class QrCodeView extends StatelessWidget {
  const QrCodeView({
    super.key,
    required this.data,
    this.size = 220,
    this.quietZoneModules = 4,
  });

  /// The text to encode (a Nostr `npub…` key).
  final String data;

  /// Edge length of the square code, including the quiet zone.
  final double size;

  /// Blank margin around the modules so scanners can lock on.
  final int quietZoneModules;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QrImage? image = _buildImage();
    if (image == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No code to show yet'),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _QrCodePainter(
          data: data,
          image: image,
          quietZoneModules: quietZoneModules,
          dark: theme.colorScheme.onSurface,
          light: theme.colorScheme.surface,
        ),
      ),
    );
  }

  /// Encodes [data], returning `null` when it is empty or cannot be encoded.
  QrImage? _buildImage() {
    final String payload = data.trim();
    if (payload.isEmpty) {
      return null;
    }
    try {
      return QrImage(
        QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
    } catch (_) {
      // Too much data for a QR code: show the placeholder instead of crashing.
      return null;
    }
  }
}

class _QrCodePainter extends CustomPainter {
  const _QrCodePainter({
    required this.data,
    required this.image,
    required this.quietZoneModules,
    required this.dark,
    required this.light,
  });

  final String data;
  final QrImage image;
  final int quietZoneModules;
  final Color dark;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);

    final int modules = image.moduleCount;
    if (modules <= 0) {
      return;
    }
    final double total = modules + quietZoneModules * 2;
    final double module = size.shortestSide / total;
    final Paint paint = Paint()
      ..color = dark
      // Crisp edges; a fractional-module overlap would blur scanning edges.
      ..isAntiAlias = false;

    for (int row = 0; row < modules; row++) {
      for (int column = 0; column < modules; column++) {
        if (!image.isDark(row, column)) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            (column + quietZoneModules) * module,
            (row + quietZoneModules) * module,
            module,
            module,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrCodePainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.dark != dark ||
      oldDelegate.light != light ||
      oldDelegate.quietZoneModules != quietZoneModules ||
      oldDelegate.image.moduleCount != image.moduleCount;
}
