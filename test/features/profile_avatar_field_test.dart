import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  test('renderProfileAvatar accepts a pan offset', () async {
    final Uint8List out = await renderProfileAvatar(
      await _png(200),
      zoom: 1.5,
      offset: const ui.Offset(0.2, -0.1),
      size: 48,
    );
    final ui.Image image = await decode(out);
    addTearDown(image.dispose);
    expect(image.width, 48);
    expect(image.height, 48);
  });

  test('clampAvatarOffset keeps the picture covering the square', () {
    // At zoom 1 a square image cannot move at all.
    expect(
      clampAvatarOffset(const ui.Offset(0.5, 0.5), zoom: 1, aspectRatio: 1),
      ui.Offset.zero,
    );
    // A wide image at zoom 1 can move horizontally, not vertically.
    final ui.Offset wide = clampAvatarOffset(
      const ui.Offset(9, 9),
      zoom: 1,
      aspectRatio: 2,
    );
    expect(wide.dx, closeTo(0.5, 1e-9));
    expect(wide.dy, 0);
    // Zooming in widens the range.
    final ui.Offset zoomed = clampAvatarOffset(
      const ui.Offset(9, 9),
      zoom: 2,
      aspectRatio: 1,
    );
    expect(zoomed.dx, closeTo(0.5, 1e-9));
    expect(zoomed.dy, closeTo(0.5, 1e-9));
  });

  test('renderProfileAvatar rejects bytes that are not an image', () async {
    await expectLater(
      renderProfileAvatar(Uint8List.fromList(<int>[1, 2, 3, 4]), size: 16),
      throwsA(anything),
    );
  });

  testWidgets('dragging the picture updates the pan', (
    WidgetTester tester,
  ) async {
    // ui image encoding needs the real event loop, not the test's FakeAsync.
    final Uint8List bytes = (await tester.runAsync(() => _png(200)))!;
    // zoom > 1 so the picture has somewhere to move.
    AvatarDraft draft = AvatarDraft(
      bytes: bytes,
      mimeType: 'image/png',
      aspectRatio: 1,
      zoom: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return ProfileAvatarField(
                    label: 'You',
                    draft: draft,
                    onChanged: (AvatarDraft? next) {
                      if (next != null) {
                        setState(() => draft = next);
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset centre = tester.getCenter(find.byType(Image));
    final TestGesture gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));

    expect(draft.offset.dy, lessThan(0));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
