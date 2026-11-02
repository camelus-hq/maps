import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// Builds the map badge for a live friend: their **profile picture** in a
/// circle with a teal ring, and a white pill underneath reading "Name · Live"
/// (mirroring the reference app's friend pin).
///
/// Everything is drawn locally with `dart:ui` — the only third-party data is the
/// friend's own avatar URL from their Nostr profile, which is fetched
/// best-effort. A missing, broken, hostile or oversized avatar falls back to a
/// monogram, so a friend pin can never break the map.
class FriendMarkerComposer {
  FriendMarkerComposer({
    this.fetchAvatar,
    http.Client? client,
    this.fetchTimeout = const Duration(seconds: 4),
    this.maxAvatarBytes = 2 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  /// Overrides the network fetch (tests); when null an HTTP GET is used.
  final Future<Uint8List?> Function(Uri uri)? fetchAvatar;

  final Duration fetchTimeout;

  /// Avatars larger than this are ignored rather than decoded.
  final int maxAvatarBytes;

  final http.Client _client;

  // --- geometry (logical pixels in the composed PNG) ---
  static const double _avatarDiameter = 96;
  static const double _ringWidth = 5;
  static const double _ringGap = 3;
  static const double _gap = 6;
  static const double _pillHeight = 36;
  static const double _pad = 8;
  static const double _dotRadius = 5;
  static const double _pillMaxWidth = 280;

  static const int _teal = 0xFF116B5B;
  static const int _tealBright = 0xFF1B9C6B;
  static const int _ink = 0xFF1B1B1B;
  static const int _white = 0xFFFFFFFF;

  /// Composed marker PNGs, keyed by avatar URL + label.
  final Map<String, Uint8List> _composed = <String, Uint8List>{};

  /// Decoded avatars (null = fetched but unusable).
  final Map<String, ui.Image?> _avatars = <String, ui.Image?>{};

  /// URLs currently being fetched, so we do not hammer a relay/CDN.
  final Set<String> _pending = <String>{};

  /// The last avatar fetch/decode failure, for diagnostics and tests.
  Object? lastAvatarError;

  /// How many avatars have been decoded successfully (diagnostics/tests).
  int get decodedAvatarCount =>
      _avatars.values.where((ui.Image? image) => image != null).length;

  /// The newest bytes for [label]/[pictureUrl], or `null` when the avatar is
  /// still being fetched (call again later, or use [prefetchAvatar]).
  Uint8List? cachedBytes({required String label, String? pictureUrl}) {
    return _composed[_cacheKey(label, pictureUrl)];
  }

  /// Composes (and caches) a marker from whatever avatar is already available;
  /// call [prefetchAvatar] alongside to fill missing avatars in later.
  Future<Uint8List> compose({
    required String label,
    String? pictureUrl,
    bool live = true,
  }) async {
    final String key = _cacheKey(label, pictureUrl);
    final Uint8List? cached = _composed[key];
    if (cached != null) {
      return cached;
    }
    final ui.Image? avatar = pictureUrl == null ? null : _avatars[pictureUrl];
    final Uint8List bytes = await _draw(
      label: label,
      avatar: avatar,
      live: live,
    );
    _composed[key] = bytes;
    return bytes;
  }

  /// Fetches and decodes [pictureUrl] when it is not cached yet. Returns true
  /// when new avatar data became available (so the caller can repaint).
  Future<bool> prefetchAvatar(String? pictureUrl) async {
    final String? url = pictureUrl;
    if (url == null ||
        url.isEmpty ||
        _avatars.containsKey(url) ||
        !_pending.add(url)) {
      return false;
    }
    try {
      final Uri? uri = Uri.tryParse(url);
      if (uri == null || !uri.hasAuthority) {
        _avatars[url] = null;
        return true;
      }
      final Future<Uint8List?> request =
          fetchAvatar?.call(uri) ?? _httpGet(uri);
      // A slow avatar must not hold the marker back: give up and fall back.
      Uint8List? bytes;
      try {
        bytes = await request.timeout(fetchTimeout);
      } on TimeoutException {
        bytes = null;
      }
      if (bytes == null || bytes.isEmpty || bytes.length > maxAvatarBytes) {
        _avatars[url] = null;
        return true;
      }
      final ui.Image? image = await _decode(bytes);
      _avatars[url] = image;
      return true;
    } catch (error) {
      // A broken avatar must never break the map.
      lastAvatarError = error;
      _avatars[url] = null;
      return true;
    } finally {
      _pending.remove(url);
    }
  }

  Future<Uint8List?> _httpGet(Uri uri) async {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    return response.bodyBytes;
  }

  Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      try {
        final ui.FrameInfo frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } catch (error) {
      lastAvatarError = error;
      return null;
    }
  }

  /// Releases cached avatars and the HTTP client.
  void dispose() {
    for (final ui.Image? image in _avatars.values) {
      image?.dispose();
    }
    _avatars.clear();
    _composed.clear();
    _client.close();
  }

  String _cacheKey(String label, String? pictureUrl) {
    final bool hasAvatar = pictureUrl != null && _avatars[pictureUrl] != null;
    return '${pictureUrl ?? ''}|$label|${hasAvatar ? 'avatar' : 'monogram'}';
  }

  Future<Uint8List> _draw({
    required String label,
    required ui.Image? avatar,
    required bool live,
  }) async {
    final TextPainter namePainter = _text(
      _clipLabel(label),
      const TextStyle(
        color: Color(_ink),
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
    );
    final TextPainter livePainter = _text(
      ' · Live',
      const TextStyle(
        color: Color(_tealBright),
        fontSize: 26,
        fontWeight: FontWeight.w500,
      ),
    );

    final double pillContent =
        _dotRadius * 2 + 10 + namePainter.width + livePainter.width;
    final double pillWidth = (pillContent + 28).clamp(
      _avatarDiameter + _pad * 2,
      _pillMaxWidth,
    );
    final double avatarOuter = _avatarDiameter + (_ringWidth + _ringGap) * 2;
    final double halfBelow = avatarOuter / 2 + _gap + _pillHeight + _pad;
    final double halfAbove = avatarOuter / 2 + _pad;
    final double halfHeight = halfBelow > halfAbove ? halfBelow : halfAbove;
    final double width = (pillWidth + _pad * 2) > (avatarOuter + _pad * 2)
        ? pillWidth + _pad * 2
        : avatarOuter + _pad * 2;
    final double height = halfHeight * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double centerX = width / 2;
    final double centerY = halfHeight;

    // The pill sits under the avatar; the avatar is drawn after it so it
    // overlaps the pill's top edge, like the reference pin.
    final ui.Rect pill = ui.Rect.fromCenter(
      center: ui.Offset(
        centerX,
        centerY + avatarOuter / 2 + _gap + _pillHeight / 2,
      ),
      width: pillWidth,
      height: _pillHeight,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        pill.shift(const ui.Offset(0, 2)),
        const ui.Radius.circular(_pillHeight),
      ),
      ui.Paint()
        ..color = const ui.Color(0x33000000)
        ..isAntiAlias = true,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(pill, const ui.Radius.circular(_pillHeight)),
      ui.Paint()
        ..color = const ui.Color(_white)
        ..isAntiAlias = true,
    );

    // Pill content: a "live" dot, the name, then " · Live".
    double cursor = pill.left + 14;
    if (live) {
      canvas.drawCircle(
        ui.Offset(cursor + _dotRadius, pill.center.dy),
        _dotRadius,
        ui.Paint()
          ..color = const ui.Color(_tealBright)
          ..isAntiAlias = true,
      );
      cursor += _dotRadius * 2 + 10;
    }
    namePainter.paint(
      canvas,
      ui.Offset(cursor, pill.center.dy - namePainter.height / 2),
    );
    cursor += namePainter.width;
    livePainter.paint(
      canvas,
      ui.Offset(cursor, pill.center.dy - livePainter.height / 2),
    );

    _paintAvatar(canvas, ui.Offset(centerX, centerY), avatar, label);

    final ui.Picture picture = recorder.endRecording();
    try {
      final ui.Image image = await picture.toImage(width.ceil(), height.ceil());
      try {
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw StateError('Could not encode the friend marker image');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Draws the circular avatar (or a monogram) with a teal ring.
  void _paintAvatar(
    ui.Canvas canvas,
    ui.Offset center,
    ui.Image? avatar,
    String label,
  ) {
    final double radius = _avatarDiameter / 2;
    final ui.Paint ring = ui.Paint()
      ..color = const ui.Color(_teal)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = _ringWidth
      ..isAntiAlias = true;

    canvas.drawCircle(
      center,
      radius + _ringWidth / 2 + _ringGap + 2,
      ui.Paint()
        ..color = const ui.Color(_white)
        ..isAntiAlias = true,
    );
    if (avatar != null) {
      canvas.save();
      canvas.clipPath(
        ui.Path()..addOval(ui.Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawImageRect(
        avatar,
        ui.Rect.fromLTWH(
          0,
          0,
          avatar.width.toDouble(),
          avatar.height.toDouble(),
        ),
        ui.Rect.fromCircle(center: center, radius: radius),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.medium
          ..isAntiAlias = true,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(
        center,
        radius,
        ui.Paint()
          ..color = const ui.Color(0xFFD9EDE9)
          ..isAntiAlias = true,
      );
      final TextPainter initial = _text(
        _initial(label),
        const TextStyle(
          color: Color(_teal),
          fontSize: 44,
          fontWeight: FontWeight.w600,
        ),
      );
      initial.paint(
        canvas,
        ui.Offset(
          center.dx - initial.width / 2,
          center.dy - initial.height / 2,
        ),
      );
    }
    canvas.drawCircle(center, radius + _ringWidth / 2 + _ringGap, ring);
  }

  static TextPainter _text(String value, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 200);
    return painter;
  }

  static String _clipLabel(String label) {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      return 'Friend';
    }
    return trimmed.length > 20 ? '${trimmed.substring(0, 20)}…' : trimmed;
  }

  static String _initial(String label) {
    final String trimmed = label.trim();
    return trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
