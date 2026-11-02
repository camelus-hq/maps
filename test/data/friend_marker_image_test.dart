import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/friend_marker_image.dart';

/// The friend pin is drawn locally: a circular avatar (or monogram) with a ring
/// and a "Name · Live" pill. It must always produce a PNG, whatever the avatar
/// does — missing, broken, oversized or hostile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> tinyAvatar() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      ui.Paint()..color = const ui.Color(0xFFFF00FF),
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(8, 8);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }

  bool isPng(Uint8List bytes) =>
      bytes.length > 8 && bytes.sublist(0, 4).join(',') == '137,80,78,71';

  test('draws a monogram marker when there is no avatar', () async {
    final FriendMarkerComposer composer = FriendMarkerComposer(
      fetchAvatar: (Uri _) async => null,
    );
    addTearDown(composer.dispose);

    final Uint8List bytes = await composer.compose(label: 'Mia');
    expect(isPng(bytes), isTrue);
  });

  test('draws the avatar once it is fetched, and caches it', () async {
    final Uint8List avatar = await tinyAvatar();
    int fetches = 0;
    final FriendMarkerComposer composer = FriendMarkerComposer(
      fetchAvatar: (Uri _) async {
        fetches++;
        return avatar;
      },
    );
    addTearDown(composer.dispose);

    final Uint8List monogram = await composer.compose(
      label: 'Mia',
      pictureUrl: 'https://example.com/mia.png',
    );
    expect(
      await composer.prefetchAvatar('https://example.com/mia.png'),
      isTrue,
    );
    final Uint8List withAvatar = await composer.compose(
      label: 'Mia',
      pictureUrl: 'https://example.com/mia.png',
    );
    // ignore: avoid_print
    print(
      'decoded avatars: ${composer.decodedAvatarCount} '
      'fetches: $fetches err: ${composer.lastAvatarError}',
    );

    expect(composer.decodedAvatarCount, 1);
    expect(composer.lastAvatarError, isNull);
    expect(isPng(withAvatar), isTrue);
    expect(withAvatar, isNot(equals(monogram)));
    // Second compose uses the cache (no re-draw, no re-fetch).
    expect(
      await composer.compose(
        label: 'Mia',
        pictureUrl: 'https://example.com/mia.png',
      ),
      equals(withAvatar),
    );
    expect(fetches, 1);
    // A repeated prefetch for a known URL is a no-op.
    expect(
      await composer.prefetchAvatar('https://example.com/mia.png'),
      isFalse,
    );
  });

  test(
    'a broken, oversized or non-http avatar falls back to the monogram',
    () async {
      final FriendMarkerComposer composer = FriendMarkerComposer(
        maxAvatarBytes: 16,
        fetchAvatar: (Uri uri) async => switch (uri.host) {
          'broken.test' => throw Exception('boom'),
          'empty.test' => Uint8List(0),
          'huge.test' => Uint8List(1024),
          _ => null,
        },
      );
      addTearDown(composer.dispose);

      for (final String url in <String>[
        'https://broken.test/a.png',
        'https://empty.test/a.png',
        'https://huge.test/a.png',
        'ftp://files.test/a.png',
        'not a url',
      ]) {
        await composer.prefetchAvatar(url);
        expect(
          isPng(await composer.compose(label: 'Sam', pictureUrl: url)),
          isTrue,
          reason: url,
        );
      }
    },
  );

  test(
    'the label is bounded so a hostile name cannot blow up the image',
    () async {
      final FriendMarkerComposer composer = FriendMarkerComposer(
        fetchAvatar: (Uri _) async => null,
      );
      addTearDown(composer.dispose);

      final Uint8List bytes = await composer.compose(label: 'x' * 500);
      expect(isPng(bytes), isTrue);
    },
  );
}
