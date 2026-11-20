import 'package:maps_api_server/src/push/push_presence.dart';
import 'package:test/test.dart';

void main() {
  group('PushPresence', () {
    test('is active only while a connection is open', () {
      final PushPresence presence = PushPresence();
      final String key = 'a'.padRight(64, 'a');

      expect(presence.isActive(key), isFalse);
      presence.add(key);
      expect(presence.isActive(key), isTrue);
      presence.remove(key);
      expect(presence.isActive(key), isFalse);
    });

    test('stays active until every overlapping connection closed', () {
      final PushPresence presence = PushPresence();
      final String key = 'b'.padRight(64, 'b');

      presence.add(key);
      presence.add(key); // a reconnect overlapping the old socket
      presence.remove(key);
      expect(presence.isActive(key), isTrue);
      presence.remove(key);
      expect(presence.isActive(key), isFalse);
    });

    test('ignores a remove without a matching add', () {
      final PushPresence presence = PushPresence();
      expect(() => presence.remove('c'.padRight(64, 'c')), returnsNormally);
      expect(presence.activeCount, 0);
    });
  });
}
