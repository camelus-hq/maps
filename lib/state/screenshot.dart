import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'commands/command.dart';

/// Boundary wrapping the whole app so a Flutter-level capture can see it.
///
/// Used by [captureAppPng] as the fallback when the native window capture
/// ([_screenshotChannel]) is unavailable or comes back empty. The platform view
/// (the Mapbox map) is a hole in this capture; [mapSnapshotProvider] supplies
/// the map that is composited into that hole (AGENTS.md §Driving the app).
final GlobalKey rootScreenshotKey = GlobalKey(
  debugLabel: 'openmaps-root-boundary',
);

/// The native window-capture channel (`MainActivity` on Android). It copies the
/// composited app window with `PixelCopy`, which leaves the Mapbox platform view
/// as a transparent hole — the map is then composited in from a Mapbox snapshot.
const MethodChannel _screenshotChannel = MethodChannel('openmaps/screenshot');

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

/// A PNG snapshot of the live map (with its annotations), or `null` when there
/// is none. Overridden at the composition root with the real map service; the
/// keyless default has no map.
final Provider<Future<Uint8List?> Function()> mapSnapshotProvider =
    Provider<Future<Uint8List?> Function()>(
      (Ref ref) =>
          () async => null,
    );

/// Captures the whole app screen as a PNG, with the map composited in.
///
/// The window capture ([_screenshotChannel]) or the Flutter boundary provides
/// the UI; [mapPng] (the live map snapshot) is drawn behind it so the platform
/// view that is a hole in both is filled in. Falls back to whichever capture
/// succeeds; never silently returns nothing (it throws a [CommandException]).
Future<Uint8List> captureAppPng({
  double pixelRatio = 0,
  Uint8List? mapPng,
}) async {
  final Uint8List window = await _captureWindowPng(pixelRatio: pixelRatio);
  if (mapPng == null || mapPng.isEmpty) {
    return window;
  }
  final Uint8List? composed = await _composeWithMap(window, mapPng);
  return composed ?? window;
}

/// The app UI as a PNG: the native window capture when it works, else the
/// Flutter repaint boundary (crisp at the device pixel ratio).
Future<Uint8List> _captureWindowPng({required double pixelRatio}) async {
  try {
    final Uint8List? bytes = await _screenshotChannel.invokeMethod<Uint8List>(
      'capture',
    );
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }
  } catch (_) {
    // Native capture unavailable (web/tests) or failed: use the boundary.
  }
  final double ratio = pixelRatio > 0
      ? pixelRatio
      : (ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0);
  return captureRootPng(pixelRatio: ratio);
}

/// Draws [mapPng] stretched under [basePng], so the map shows through the
/// (transparent) platform-view hole in the UI capture. Returns `null` when the
/// images cannot be decoded/composed, so the caller keeps the plain UI capture.
Future<Uint8List?> _composeWithMap(Uint8List basePng, Uint8List mapPng) async {
  ui.Image? base;
  ui.Image? map;
  ui.Picture? picture;
  ui.Image? composed;
  try {
    base = await _decodePng(basePng);
    map = await _decodePng(mapPng);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double width = base.width.toDouble();
    final double height = base.height.toDouble();
    canvas
      ..drawImageRect(
        map,
        ui.Rect.fromLTWH(0, 0, map.width.toDouble(), map.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint(),
      )
      ..drawImageRect(
        base,
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint(),
      );
    picture = recorder.endRecording();
    composed = await picture.toImage(base.width, base.height);
    final ByteData? data = await composed.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    base?.dispose();
    map?.dispose();
    picture?.dispose();
    composed?.dispose();
  }
}

Future<ui.Image> _decodePng(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

/// How a caller obtains a screenshot. Injectable so tests (and the control
/// channel) can substitute a fixed image without a platform channel.
typedef ScreenshotCapture = Future<Uint8List> Function();

/// The app's screenshot source: the UI capture with the live map composited in.
/// Tests override it with a fixed image.
final Provider<ScreenshotCapture> screenshotCaptureProvider =
    Provider<ScreenshotCapture>((Ref ref) {
      return () async {
        Uint8List? mapPng;
        try {
          mapPng = await ref.read(mapSnapshotProvider)();
        } catch (_) {
          // No map snapshot: the screenshot is the UI without the map.
        }
        return captureAppPng(mapPng: mapPng);
      };
    });
