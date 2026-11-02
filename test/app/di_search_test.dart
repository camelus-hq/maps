import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/di.dart';
import 'package:openmaps/core/config/app_config.dart';
import 'package:openmaps/data/fakes/fake_settings_repository.dart';
import 'package:openmaps/data/mapbox/mapbox_search_service.dart';
import 'package:openmaps/data/osm/osm_search_service.dart';
import 'package:openmaps/domain/entities/app_settings.dart';
import 'package:openmaps/domain/ports/search_service.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/settings.dart';

/// The DI search wiring: the settings choice picks the adapter, and a "mapbox"
/// or "camelus" choice without its key falls back to OpenStreetMap so search
/// keeps working key-less.
void main() {
  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
    ],
  );

  Provider<SearchService> probe(AppConfig config) =>
      Provider<SearchService>((Ref ref) => buildSearchService(ref, config));

  test('the default Mapbox setting builds the Mapbox adapter', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    const AppConfig config = AppConfig(mapboxAccessToken: 'pk.test');

    expect(container.read(probe(config)), isA<MapboxSearchService>());
  });

  test('selecting OpenStreetMap builds the Photon/Overpass adapter', () async {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    const AppConfig config = AppConfig(mapboxAccessToken: 'pk.test');

    await container
        .read(settingsProvider.notifier)
        .setSearchBackend(SearchBackend.openstreetmap);

    expect(container.read(probe(config)), isA<OsmSearchService>());
  });

  test('selecting Camelus points Photon/Overpass at camelus.app', () async {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);
    const AppConfig config = AppConfig(camelusApiToken: 'ck.test');

    await container
        .read(settingsProvider.notifier)
        .setSearchBackend(SearchBackend.camelus);

    final SearchService service = container.read(probe(config));
    expect(service, isA<OsmSearchService>());
    final OsmSearchService osm = service as OsmSearchService;
    expect(osm.photonBaseUrl, AppConfig.defaultCamelusPhotonBaseUrl);
    expect(osm.overpassBaseUrl, AppConfig.defaultCamelusOverpassBaseUrl);
  });

  test('Mapbox without a token falls back to OpenStreetMap', () {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);

    expect(container.read(probe(AppConfig.empty)), isA<OsmSearchService>());
  });

  test('Camelus without a key falls back to OpenStreetMap', () async {
    final ProviderContainer container = makeContainer();
    addTearDown(container.dispose);

    await container
        .read(settingsProvider.notifier)
        .setSearchBackend(SearchBackend.camelus);

    final SearchService service = container.read(probe(AppConfig.empty));
    expect(service, isA<OsmSearchService>());
    expect(
      (service as OsmSearchService).photonBaseUrl,
      AppConfig.defaultPhotonBaseUrl,
    );
  });
}
