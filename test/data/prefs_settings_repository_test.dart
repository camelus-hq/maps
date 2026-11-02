import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/local/prefs_settings_repository.dart';
import 'package:openmaps/domain/entities/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('defaults to the shipped pinned chips when nothing is stored', () async {
    final AppSettings settings = await PrefsSettingsRepository().load();
    expect(settings.pinnedCategoryIds, <String>[
      'park',
      'cafe',
      'drinking_water',
      'grocery',
      'toilets',
    ]);
  });

  test('pinned categories round-trip across repository instances', () async {
    final PrefsSettingsRepository repo = PrefsSettingsRepository();
    await repo.save(
      const AppSettings().copyWith(
        pinnedCategoryIds: const <String>['cafe', 'toilets'],
      ),
    );

    expect((await PrefsSettingsRepository().load()).pinnedCategoryIds, <String>[
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

    expect((await PrefsSettingsRepository().load()).pinnedCategoryIds, <String>[
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

    expect(
      (await PrefsSettingsRepository().load()).pinnedCategoryIds,
      hasLength(10),
    );
  });

  test(
    'a stored list that resolves to nothing falls back to the defaults',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'openmaps.search.pinnedCategories': <String>['gone', 'also-gone'],
      });

      expect(
        (await PrefsSettingsRepository().load()).pinnedCategoryIds,
        hasLength(5),
      );
    },
  );

  test('the search provider round-trips for every backend', () async {
    for (final SearchBackend backend in SearchBackend.values) {
      await PrefsSettingsRepository().save(AppSettings(searchBackend: backend));
      expect(
        (await PrefsSettingsRepository().load()).searchBackend,
        backend,
        reason: '${backend.name} must survive a reload',
      );
    }
  });

  test('an unknown stored search provider falls back to Mapbox', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'openmaps.search.backend': 'retired-provider',
    });

    expect(
      (await PrefsSettingsRepository().load()).searchBackend,
      SearchBackend.mapbox,
    );
  });
}
