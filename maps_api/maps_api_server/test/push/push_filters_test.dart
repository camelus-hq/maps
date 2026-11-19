import 'package:maps_api_server/src/push/push_config.dart';
import 'package:maps_api_server/src/push/push_filters.dart';
import 'package:test/test.dart';

void main() {
  group('buildPushFilters', () {
    test('is empty when nobody is registered', () {
      expect(buildPushFilters(const <String>[]), isEmpty);
    });

    test('asks only for the registered pubkeys', () {
      final String pubkey = 'a' * 64;
      final Map<String, Map<String, Object>> filters = buildPushFilters(
        <String>[pubkey],
      );

      expect(filters, hasLength(1));
      final Map<String, Object> filter = filters.values.single;
      expect(filter['#p'], <String>[pubkey]);
      expect(filter['kinds'], PushConfig.availableKinds);
      expect(filter['limit'], 0);
    });

    test('chunks more than pubkeysPerFilter pubkeys', () {
      final List<String> pubkeys = <String>[
        for (int i = 0; i <= PushConfig.pubkeysPerFilter; i++)
          i.toRadixString(16).padLeft(64, '0'),
      ];

      final Map<String, Map<String, Object>> filters = buildPushFilters(
        pubkeys,
      );

      expect(filters, hasLength(2));
    });

    test('drops invalid and duplicate pubkeys', () {
      final String valid = 'b' * 64;
      final Map<String, Map<String, Object>> filters = buildPushFilters(
        <String>[valid, valid.toUpperCase(), 'not-a-pubkey'],
      );

      expect(filters.values.single['#p'], <String>[valid]);
    });
  });
}
