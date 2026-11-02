import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/local/prefs_places_repository.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('records recent queries deduped, most recent first', () async {
    final PrefsPlacesRepository repo = PrefsPlacesRepository();
    await repo.recordQuery('coffee');
    await repo.recordQuery('pizza');
    await repo.recordQuery('coffee');
    expect(await repo.recentQueries(), <String>['coffee', 'pizza']);
  });

  test('caps the recent query list', () async {
    final PrefsPlacesRepository repo = PrefsPlacesRepository();
    for (int i = 0; i < 15; i++) {
      await repo.recordQuery('q$i');
    }
    expect((await repo.recentQueries()).length, 10);
  });

  test('bookmarks round-trip across repository instances', () async {
    const Place place = Place(id: 'x', name: 'X', position: LatLon(1, 2));
    await PrefsPlacesRepository().setBookmark(place, bookmarked: true);

    final PrefsPlacesRepository repo = PrefsPlacesRepository();
    expect(await repo.bookmarks(), hasLength(1));
    expect(await repo.placeById('x'), place);

    await repo.setBookmark(place, bookmarked: false);
    expect(await repo.bookmarks(), isEmpty);
    expect(await repo.placeById('x'), isNull);
  });

  test('corrupted bookmark JSON is ignored, not fatal', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'openmaps.bookmarks': '{ this is not json',
    });
    expect(await PrefsPlacesRepository().bookmarks(), isEmpty);
  });

  test('clearRecentQueries empties the list', () async {
    final PrefsPlacesRepository repo = PrefsPlacesRepository();
    await repo.recordQuery('a');
    await repo.clearRecentQueries();
    expect(await repo.recentQueries(), isEmpty);
  });
}
