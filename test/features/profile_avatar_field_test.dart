import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/features/social/widgets/profile_avatar_field.dart';

/// Builds a real PNG so the render path has valid input (a hand-written base64
/// blob is fragile).
Future<Uint8List> _png(int size) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Rect rect = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  final ui.Canvas canvas = ui.Canvas(recorder, rect);
  canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFF3366CC));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(size, size);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> decode(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  test(
    'renderProfileAvatar outputs a square PNG at the requested size',
    () async {
      final Uint8List out = await renderProfileAvatar(
        await _png(120),
        size: 64,
      );
      final ui.Image image = await decode(out);
      addTearDown(image.dispose);
      expect(image.width, 64);
      expect(image.height, 64);
    },
  );

  test('renderProfileAvatar copes with a zoom factor', () async {
    final Uint8List out = await renderProfileAvatar(
      await _png(200),
      zoom: 2.5,
      size: 32,
    );
    final ui.Image image = await decode(out);
    addTearDown(image.dispose);
    expect(image.width, 32);
    expect(image.height, 32);
  });

  test('renderProfileAvatar rejects bytes that are not an image', () async {
    await expectLater(
      renderProfileAvatar(Uint8List.fromList(<int>[1, 2, 3, 4]), size: 16),
      throwsA(anything),
    );
  });
}
