import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/local/local_settings_repository.dart';
import 'package:openmaps/domain/entities/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  LocalSettingsRepository repository([InMemoryAppDatabase? database]) =>
      LocalSettingsRepository(database: database ?? InMemoryAppDatabase());

  test('defaults to the shipped pinned chips when nothing is stored', () async {
    final AppSettings settings = await repository().load();
    expect(settings.pinnedCategoryIds, <String>[
      'park',
      'cafe',
      'drinking_water',
      'grocery',
      'toilets',
    ]);
  });

  test('pinned categories round-trip across repository instances', () async {
    final InMemoryAppDatabase database = InMemoryAppDatabase();
    await repository(database).save(
      const AppSettings().copyWith(
        pinnedCategoryIds: const <String>['cafe', 'toilets'],
      ),
    );

    expect((await repository(database).load()).pinnedCategoryIds, <String>[
      'cafe',
      'toilets',
    ]);
  });

  test('an unknown stored id is dropped and duplicates collapse', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'openmaps.search.pinnedCategories': <String>[
        'cafe',
        'nope',
        'cafe',
        'park',
      ],
    });

    expect((await repository().load()).pinnedCategoryIds, <String>[
      'cafe',
      'park',
    ]);
  });

  test('the stored list is capped at the pin limit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'openmaps.search.pinnedCategories': <String>[
        'cafe',
        'park',
        'toilets',
        'grocery',
        'hotel',
        'atm',
        'bank',
        'pharmacy',
        'cinema',
        'parking',
        'restaurant',
        'bar',
      ],
    });

    expect((await repository().load()).pinnedCategoryIds, hasLength(10));
  });

  test(
    'a stored list that resolves to nothing falls back to the defaults',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'openmaps.search.pinnedCategories': <String>['gone', 'also-gone'],
      });

      expect((await repository().load()).pinnedCategoryIds, hasLength(5));
    },
  );

  test('the search provider round-trips for every backend', () async {
    final InMemoryAppDatabase database = InMemoryAppDatabase();
    for (final SearchBackend backend in SearchBackend.values) {
      await repository(database).save(AppSettings(searchBackend: backend));
      expect(
        (await repository(database).load()).searchBackend,
        backend,
        reason: '${backend.name} must survive a reload',
      );
    }
  });

  test('an unknown stored search provider falls back to Mapbox', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'openmaps.search.backend': 'retired-provider',
    });

    expect((await repository().load()).searchBackend, SearchBackend.mapbox);
  });

  test(
    'the theme stays in shared_preferences, the rest in the database',
    () async {
      final InMemoryAppDatabase database = InMemoryAppDatabase();
      await repository(database).save(
        const AppSettings(
          unit: DistanceUnit.imperial,
          theme: AppThemeMode.dark,
          showOsmTags: true,
        ),
      );

      // The theme is persisted in shared_preferences...
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('openmaps.theme'), 'dark');
      // ...while the other settings only live in the database.
      expect(await database.readSetting('settings.unit'), isNotNull);
      expect((await repository(database).load()).theme, AppThemeMode.dark);
    },
  );

  test('onboarding and the skipped update version stay in prefs', () async {
    final LocalSettingsRepository repo = repository();
    expect(await repo.onboardingSeen(), isFalse);
    await repo.setOnboardingSeen(true);
    expect(await repo.onboardingSeen(), isTrue);

    expect(await repo.skippedUpdateVersionCode(), isNull);
    await repo.setSkippedUpdateVersionCode(42);
    expect(await repo.skippedUpdateVersionCode(), 42);
    await repo.setSkippedUpdateVersionCode(null);
    expect(await repo.skippedUpdateVersionCode(), isNull);
  });
}
