import 'dart:convert';

import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/live_share.dart';

/// Wire codec for the live-location "rumor" carried inside a NIP-59 gift wrap.
///
/// No standard NIP covers live location yet, so this is our own small,
/// versioned JSON schema. Decoding is **hostile safe**: a truncated, oversized,
/// mistyped or out-of-range payload returns `null` instead of throwing, so a
/// malformed event off a relay can never crash the app (AGENTS.md "Never
/// crash").
class LiveLocationPayload {
  const LiveLocationPayload({
    required this.isStop,
    required this.sessionId,
    required this.position,
    required this.sampledAt,
    required this.expiresAt,
    this.accuracyMeters,
    this.heading,
    this.displayName,
  });

  /// Schema version this codec speaks.
  static const int version = 1;

  /// Rumor event kind for a live-location event (inside the gift wrap).
  static const int rumorKind = 20510;

  /// Tag that names our feature, so a recipient can ignore unrelated kinds.
  static const String featureTag = 'openmaps-live-location';

  /// Tag carrying the session id.
  static const String sessionTag = 'session';

  static const String _typeUpdate = 'update';
  static const String _typeStop = 'stop';

  static const int _maxSessionIdLength = 64;
  static const int _maxNameLength = 60;
  static const double _maxAccuracyMeters = 100000;
  static const Duration _maxLifetime = Duration(hours: 12);
  static const Duration _maxClockSkew = Duration(minutes: 5);

  /// Whether this payload ends the session instead of updating it.
  final bool isStop;

  /// The share session this payload belongs to.
  final String sessionId;

  /// The sampled position; `null` only when a stop arrived without one.
  final LatLon? position;

  /// When the position was sampled.
  final DateTime sampledAt;

  /// When the session ends on its own.
  final DateTime expiresAt;

  final double? accuracyMeters;
  final double? heading;
  final String? displayName;

  /// Encodes [broadcast] for the wire.
  static String encode(LiveShareBroadcast broadcast) {
    final LatLon? position = broadcast.position;
    final String? name = broadcast.displayName?.trim();
    return jsonEncode(<String, Object?>{
      'v': version,
      't': broadcast.kind == LiveShareBroadcastKind.stop
          ? _typeStop
          : _typeUpdate,
      'session': broadcast.sessionId,
      'at': broadcast.sampledAt.millisecondsSinceEpoch ~/ 1000,
      'exp': broadcast.expiresAt.millisecondsSinceEpoch ~/ 1000,
      if (position != null) 'lat': position.latitude,
      if (position != null) 'lon': position.longitude,
      if (broadcast.accuracyMeters != null) 'acc': broadcast.accuracyMeters,
      if (broadcast.heading != null) 'hdg': broadcast.heading,
      if (name != null && name.isNotEmpty)
        'name': name.length > _maxNameLength
            ? name.substring(0, _maxNameLength)
            : name,
    });
  }

  /// Decodes a plaintext rumor payload, returning `null` for anything that is
  /// not a well-formed, in-range live-location message.
  static LiveLocationPayload? decode(Object? raw) {
    final Object? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        return null;
      }
    } else {
      decoded = raw;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    if (_asInt(decoded['v']) != version) {
      return null;
    }
    final Object? type = decoded['t'];
    final bool isStop = type == _typeStop;
    if (!isStop && type != _typeUpdate) {
      return null;
    }
    final String? sessionId = _asBoundedString(
      decoded['session'],
      _maxSessionIdLength,
    );
    if (sessionId == null) {
      return null;
    }
    final int? sampledSeconds = _asInt(decoded['at']);
    final int? expiresSeconds = _asInt(decoded['exp']);
    if (sampledSeconds == null || expiresSeconds == null) {
      return null;
    }
    final DateTime sampledAt = DateTime.fromMillisecondsSinceEpoch(
      sampledSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final DateTime expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiresSeconds * 1000,
      isUtc: true,
    ).toLocal();
    // A payload that never expires, expires in the past, or runs absurdly long
    // is not something we will pin on the map.
    final DateTime now = DateTime.now();
    if (!expiresAt.isAfter(sampledAt)) {
      return null;
    }
    if (expiresAt.difference(sampledAt) > _maxLifetime) {
      return null;
    }
    if (sampledAt.isAfter(now.add(_maxClockSkew))) {
      return null;
    }
    final LatLon? position = LatLon.tryParse(decoded['lat'], decoded['lon']);
    if (!isStop && position == null) {
      return null;
    }
    final double? accuracy = _asBoundedDouble(
      decoded['acc'],
      min: 0,
      max: _maxAccuracyMeters,
    );
    final double? heading = _asBoundedDouble(decoded['hdg'], min: 0, max: 360);
    final String? name = _asBoundedString(decoded['name'], _maxNameLength);
    return LiveLocationPayload(
      isStop: isStop,
      sessionId: sessionId,
      position: position,
      sampledAt: sampledAt,
      expiresAt: expiresAt,
      accuracyMeters: accuracy,
      heading: heading,
      displayName: name,
    );
  }

  /// Converts a decoded update into a [LiveShareBroadcast] (round-trip helper
  /// for tests and the fake service).
  LiveShareBroadcast toBroadcast() => LiveShareBroadcast(
    sessionId: sessionId,
    kind: isStop ? LiveShareBroadcastKind.stop : LiveShareBroadcastKind.update,
    position: position,
    sampledAt: sampledAt,
    expiresAt: expiresAt,
    accuracyMeters: accuracyMeters,
    heading: heading,
    displayName: displayName,
  );

  static int? _asInt(Object? value) => switch (value) {
    final int v => v,
    final double v => v.isFinite ? v.truncate() : null,
    final String v => int.tryParse(v),
    _ => null,
  };

  static double? _asBoundedDouble(
    Object? value, {
    required double min,
    required double max,
  }) {
    final double? parsed = switch (value) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite || parsed < min || parsed > max) {
      return null;
    }
    return parsed;
  }

  static String? _asBoundedString(Object? value, int maxLength) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }
    return trimmed;
  }
}
