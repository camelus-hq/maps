import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/local/database/app_database_values.dart';
import 'package:openmaps/data/local/database/database_places_repository.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/recent_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  const Place coffee = Place(
    id: 'poi.coffee',
    name: 'Harbour Coffee',
    position: LatLon(52.5208, 13.4095),
    category: 'Cafe',
    address: 'Alexanderufer 1, Berlin',
  );
  const Place shop = Place(
    id: 'poi.shop',
    name: 'REWE',
    position: LatLon(52.52, 13.40),
    address: 'Hauptstraße 1, Berlin',
  );

  test(
    'recent places and queries are recorded newest-first, deduped',
    () async {
      final repo = DatabasePlacesRepository(database: InMemoryAppDatabase());
      await repo.recordRecentQuery('coffee');
      await repo.recordRecentPlace(shop);
      await repo.recordRecentPlace(coffee);
      await repo.recordRecentQuery('coffee'); // moves the query back to the top

      final List<RecentSearch> recent = await repo.recentSearches();
      expect(recent.map((RecentSearch e) => e.key), <String>[
        'query:coffee',
        'place:poi.coffee',
        'place:poi.shop',
      ]);
    },
  );

  test('the recent list is capped at 20', () async {
    final repo = DatabasePlacesRepository(database: InMemoryAppDatabase());
    for (int i = 0; i < 30; i++) {
      await repo.recordRecentQuery('q$i');
    }
    expect((await repo.recentSearches()).length, 20);
  });

  test('a single recent entry can be removed', () async {
    final repo = DatabasePlacesRepository(database: InMemoryAppDatabase());
    await repo.recordRecentPlace(coffee);
    await repo.recordRecentQuery('coffee');
    await repo.removeRecentSearch(const RecentTextSearch('coffee'));
    final List<RecentSearch> recent = await repo.recentSearches();
    expect(recent, hasLength(1));
    expect(recent.single, isA<RecentPlaceSearch>());
  });

  test('clearRecentSearches empties the list but keeps home/work', () async {
    final repo = DatabasePlacesRepository(database: InMemoryAppDatabase());
    await repo.recordRecentPlace(coffee);
    await repo.setHome(shop);
    await repo.clearRecentSearches();
    expect(await repo.recentSearches(), isEmpty);
    expect(await repo.home(), shop);
  });

  test('home and work round-trip and can be cleared', () async {
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    final repo = DatabasePlacesRepository(database: db);
    expect(await repo.home(), isNull);
    expect(await repo.work(), isNull);

    await repo.setHome(coffee);
    await repo.setWork(shop);
    // A fresh repository over the same store sees the saved places.
    final repo2 = DatabasePlacesRepository(database: db);
    expect(await repo2.home(), coffee);
    expect(await repo2.work(), shop);

    await repo2.setHome(null);
    expect(await repo.home(), isNull);
  });

  test('placeById resolves bookmarks, home, work and recents', () async {
    final repo = DatabasePlacesRepository(database: InMemoryAppDatabase());
    await repo.setBookmark(coffee, bookmarked: true);
    await repo.setHome(shop);
    const Place recent = Place(
      id: 'node/recent',
      name: 'Recent',
      position: LatLon(52.5, 13.4),
    );
    await repo.recordRecentPlace(recent);
    expect(await repo.placeById('poi.coffee'), coffee);
    expect(await repo.placeById('poi.shop'), shop);
    expect(await repo.placeById('node/recent'), recent);
    expect(await repo.placeById('missing'), isNull);
  });

  test('corrupted stored JSON reads back empty, not fatal', () async {
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    await db.writeSetting('places.recent', '{ not json');
    await db.writeSetting('places.bookmarks', 'not a list');
    await db.writeSetting('places.home', '{"id":"x"}');
    await db.writeBool('places.migratedFromPrefs', true);
    final repo = DatabasePlacesRepository(database: db);
    expect(await repo.recentSearches(), isEmpty);
    expect(await repo.bookmarks(), isEmpty);
    expect(await repo.home(), isNull);
  });

  test('legacy prefs searches and bookmarks are imported once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'openmaps.recent_queries': <String>['pizza', 'coffee'],
      'openmaps.bookmarks': '[{"id":"x","name":"X","lat":1.0,"lon":2.0}]',
    });
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    final repo = DatabasePlacesRepository(database: db);

    expect(
      (await repo.recentSearches()).map((RecentSearch e) => e.key),
      <String>['query:pizza', 'query:coffee'],
    );
    expect((await repo.bookmarks()).single.id, 'x');
    // A new value recorded afterwards is not clobbered by a second import.
    await repo.recordRecentQuery('tea');
    final repo2 = DatabasePlacesRepository(database: db);
    expect((await repo2.recentSearches()).first.key, 'query:tea');
  });
}
