import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'commands/command.dart';

/// Boundary wrapping the whole app so `ui.screenshot` can capture it.
///
/// A Flutter-level capture is accurate while the map is a plain widget; once
/// the Mapbox platform view lands (M2) this moves to a native capture channel,
/// with `adb exec-out screencap` as the cross-check (AGENTS.md §Driving the app).
final GlobalKey rootScreenshotKey = GlobalKey(
  debugLabel: 'openmaps-root-boundary',
);

Future<Uint8List> captureRootPng({double pixelRatio = 1.0}) async {
  final BuildContext? context = rootScreenshotKey.currentContext;
  if (context == null) {
    throw const CommandException('no_view', 'App view is not mounted');
  }
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw const CommandException(
      'no_boundary',
      'Root is not a repaint boundary',
    );
  }
  final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
  try {
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (data == null) {
      throw const CommandException(
        'encode_failed',
        'Could not encode the frame as PNG',
      );
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
