import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/local/database/app_database_values.dart';
import 'package:openmaps/data/local/database/database_live_share_preferences.dart';
import 'package:openmaps/domain/entities/live_share.dart';

void main() {
  const String mira =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const String timo =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  DatabaseLiveSharePreferences preferences(InMemoryAppDatabase database) =>
      DatabaseLiveSharePreferences(database: database);

  test('round-trips the remembered recipients and duration', () async {
    final InMemoryAppDatabase database = InMemoryAppDatabase();
    await preferences(database).save(
      const LiveShareDefaults(
        recipients: <String>[mira, timo],
        duration: Duration(hours: 24),
      ),
    );

    final LiveShareDefaults loaded = await preferences(database).load();
    expect(loaded.recipients, <String>[mira, timo]);
    expect(loaded.duration, const Duration(hours: 24));
  });

  test('nothing stored reads back as empty', () async {
    final LiveShareDefaults loaded = await preferences(InMemoryAppDatabase())
        .load();
    expect(loaded.isEmpty, isTrue);
    expect(loaded.recipients, isEmpty);
    expect(loaded.duration, isNull);
  });

  test(
    'a duration that is no longer an option reads back as not set',
    () async {
      final InMemoryAppDatabase database = InMemoryAppDatabase();
      await database.writeInt(
        DatabaseLiveSharePreferences.durationMinutesKey,
        999,
      );

      expect((await preferences(database).load()).duration, isNull);
    },
  );

  test('non-hex recipients are dropped on load', () async {
    final InMemoryAppDatabase database = InMemoryAppDatabase();
    await database.writeStringList(
      DatabaseLiveSharePreferences.recipientsKey,
      <String>['not-a-pubkey', mira],
    );

    expect((await preferences(database).load()).recipients, <String>[mira]);
  });

  test('saving without a duration clears the stored one', () async {
    final InMemoryAppDatabase database = InMemoryAppDatabase();
    await preferences(database)
        .save(const LiveShareDefaults(recipients: <String>[mira]));

    expect(
      await database.readSetting(
        DatabaseLiveSharePreferences.durationMinutesKey,
      ),
      isNull,
    );
    expect((await preferences(database).load()).duration, isNull);
  });
}
