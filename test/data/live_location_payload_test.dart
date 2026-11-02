import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/nostr/live_location_payload.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/live_share.dart';

/// The live-location wire codec: a round trip must survive, and anything
/// malformed, out of range or hostile must decode to `null` (never throw).
void main() {
  final DateTime now = DateTime.now();

  LiveShareBroadcast update({LatLon? position, String? name}) =>
      LiveShareBroadcast(
        sessionId: 'session-1',
        kind: LiveShareBroadcastKind.update,
        position: position ?? const LatLon(52.52, 13.405),
        sampledAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        accuracyMeters: 12.5,
        heading: 90,
        displayName: name,
      );

  test('round-trips an update', () {
    final String encoded = LiveLocationPayload.encode(update(name: 'Mira'));
    final LiveLocationPayload? decoded = LiveLocationPayload.decode(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.isStop, isFalse);
    expect(decoded.sessionId, 'session-1');
    expect(decoded.position, const LatLon(52.52, 13.405));
    expect(decoded.accuracyMeters, 12.5);
    expect(decoded.heading, 90);
    expect(decoded.displayName, 'Mira');
    expect(
      decoded.expiresAt.millisecondsSinceEpoch ~/ 1000,
      (now.add(const Duration(hours: 1))).millisecondsSinceEpoch ~/ 1000,
    );
  });

  test('round-trips a stop that carries no position', () {
    final String encoded = LiveLocationPayload.encode(
      LiveShareBroadcast(
        sessionId: 'session-1',
        kind: LiveShareBroadcastKind.stop,
        position: null,
        sampledAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      ),
    );
    final LiveLocationPayload? decoded = LiveLocationPayload.decode(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.isStop, isTrue);
    expect(decoded.position, isNull);
  });

  test('decodes a raw map as well as a JSON string', () {
    final String encoded = LiveLocationPayload.encode(update());
    final Object? asMap = jsonDecode(encoded);
    expect(LiveLocationPayload.decode(asMap), isNotNull);
  });

  test('ignores unknown fields (schema drift is tolerated)', () {
    final Map<String, Object?> raw = jsonDecode(
      LiveLocationPayload.encode(update()),
    ) as Map<String, Object?>;
    raw['future'] = <String, Object?>{'nested': true};
    raw['name'] = 'Mira';
    final LiveLocationPayload? decoded = LiveLocationPayload.decode(raw);
    expect(decoded, isNotNull);
  });

  test('never throws on hostile payloads', () {
    final List<Object?> hostile = <Object?>[
      null,
      42,
      'not json',
      '{}',
      '[]',
      <String, Object?>{},
      <Object?>[],
      <String, Object?>{'v': 1},
      <String, Object?>{'v': 'x', 't': 'update', 'session': 's'},
      <String, Object?>{
        'v': 1,
        't': 'other',
        'session': 's',
        'at': 1,
        'exp': 2,
      },
    ];
    for (final Object? raw in hostile) {
      expect(
        () => LiveLocationPayload.decode(raw),
        returnsNormally,
        reason: 'raw: $raw',
      );
      expect(
        LiveLocationPayload.decode(raw),
        isNull,
        reason: 'raw: $raw should be rejected',
      );
    }
  });

  test('rejects an unknown schema version', () {
    final Map<String, Object?> raw = jsonDecode(
      LiveLocationPayload.encode(update()),
    ) as Map<String, Object?>;
    raw['v'] = 999;
    expect(LiveLocationPayload.decode(raw), isNull);
  });

  test('rejects out-of-range and non-finite coordinates', () {
    for (final Object? latitude in <Object?>[999, -999, 'x', double.nan]) {
      final Map<String, Object?> raw = jsonDecode(
        LiveLocationPayload.encode(update()),
      ) as Map<String, Object?>;
      raw['lat'] = latitude;
      expect(LiveLocationPayload.decode(raw), isNull, reason: 'lat: $latitude');
    }
  });

  test('rejects an update without a position', () {
    final Map<String, Object?> raw = jsonDecode(
      LiveLocationPayload.encode(update()),
    ) as Map<String, Object?>;
    raw.remove('lat');
    raw.remove('lon');
    expect(LiveLocationPayload.decode(raw), isNull);
  });

  test('rejects an expiry in the past or beyond the maximum lifetime', () {
    final int sampled = now.millisecondsSinceEpoch ~/ 1000;
    for (final int expires in <int>[
      sampled - 10,
      sampled,
      sampled + const Duration(hours: 13).inSeconds,
    ]) {
      final Map<String, Object?> raw = <String, Object?>{
        'v': 1,
        't': 'update',
        'session': 's',
        'at': sampled,
        'exp': expires,
        'lat': 52.52,
        'lon': 13.405,
      };
      expect(
        LiveLocationPayload.decode(raw),
        isNull,
        reason: 'expires: $expires',
      );
    }
  });

  test('rejects a sample time far in the future', () {
    final int future =
        now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
    final Map<String, Object?> raw = <String, Object?>{
      'v': 1,
      't': 'update',
      'session': 's',
      'at': future,
      'exp': future + 3600,
      'lat': 52.52,
      'lon': 13.405,
    };
    expect(LiveLocationPayload.decode(raw), isNull);
  });

  test('bounds hostile strings and numbers', () {
    final Map<String, Object?> raw = jsonDecode(
      LiveLocationPayload.encode(update()),
    ) as Map<String, Object?>;
    raw['session'] = 'x' * 1000;
    expect(LiveLocationPayload.decode(raw), isNull);

    final Map<String, Object?> longName = jsonDecode(
      LiveLocationPayload.encode(update()),
    ) as Map<String, Object?>;
    longName['name'] = 'n' * 500;
    final LiveLocationPayload? decoded = LiveLocationPayload.decode(longName);
    expect(decoded, isNotNull);
    expect(decoded!.displayName, isNull);

    final Map<String, Object?> badAccuracy = jsonDecode(
      LiveLocationPayload.encode(update()),
    ) as Map<String, Object?>;
    badAccuracy['acc'] = 1e12;
    final LiveLocationPayload? accuracy = LiveLocationPayload.decode(
      badAccuracy,
    );
    expect(accuracy, isNotNull);
    expect(accuracy!.accuracyMeters, isNull);
  });

  test('a decoded update can be re-encoded (round trip through broadcast)', () {
    final LiveLocationPayload decoded = LiveLocationPayload.decode(
      LiveLocationPayload.encode(update(name: 'Timo')),
    )!;
    final LiveLocationPayload again = LiveLocationPayload.decode(
      LiveLocationPayload.encode(decoded.toBroadcast()),
    )!;
    expect(again.sessionId, decoded.sessionId);
    expect(again.position, decoded.position);
    expect(again.isStop, decoded.isStop);
    expect(again.displayName, 'Timo');
  });
}
