import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_live_share_store.dart';
import 'package:openmaps/data/local/prefs_live_share_store.dart';
import 'package:openmaps/domain/entities/live_share.dart';

void main() {
  const String recipient =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('a session round-trips through the prefs codec', () {
    final DateTime now = DateTime.now();
    final LiveShareSession session = LiveShareSession(
      sessionId: 'abc',
      recipients: const <String>[recipient],
      startedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );

    final LiveShareSession? decoded = PrefsLiveShareStore.decodeSession(
      PrefsLiveShareStore.encodeSession(session),
    );
    expect(decoded, isNotNull);
    expect(decoded!.sessionId, 'abc');
    expect(decoded.recipients, <String>[recipient]);
    expect(
      decoded.expiresAt.millisecondsSinceEpoch,
      session.expiresAt.millisecondsSinceEpoch,
    );
  });

  test('non-hex recipients are dropped, invalid windows rejected', () {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final LiveShareSession? decoded = PrefsLiveShareStore.decodeSession(
      '{"id":"abc","recipients":["nope","$recipient"],'
      '"startedAt":$now,"expiresAt":${now + 3600000}}',
    );
    expect(decoded, isNotNull);
    expect(decoded!.recipients, <String>[recipient]);

    expect(
      PrefsLiveShareStore.decodeSession(
        '{"id":"abc","recipients":[],"startedAt":${now + 1000},'
        '"expiresAt":$now}',
      ),
      isNull,
    );
  });

  test('the fake store records saves and clears', () async {
    final FakeLiveShareStore store = FakeLiveShareStore();
    expect(await store.load(), isNull);

    final LiveShareSession session = LiveShareSession(
      sessionId: 's',
      recipients: const <String>[recipient],
      startedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
    await store.save(session);
    expect(store.saves, 1);
    expect(await store.load(), session);

    await store.clear();
    expect(store.clears, 1);
    expect(await store.load(), isNull);
  });
}
