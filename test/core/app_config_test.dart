import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('empty config reports no backends', () {
      expect(AppConfig.empty.hasMapboxToken, isFalse);
      expect(AppConfig.empty.hasValhallaEndpoint, isFalse);
    });

    test('hasMapboxToken is true only for non-empty tokens', () {
      const AppConfig config = AppConfig(mapboxAccessToken: 'pk.test');
      expect(config.hasMapboxToken, isTrue);
      expect(config.hasValhallaEndpoint, isFalse);
    });

    test('review relays and Blossom servers default to usable hosts', () {
      // Verified live 2026-10-20: nos.social blocks kind 31987, so it must not
      // be in the default review relays.
      expect(AppConfig.defaultReviewRelays, isNotEmpty);
      expect(
        AppConfig.defaultReviewRelays.any(
          (String relay) => relay.contains('nos.social'),
        ),
        isFalse,
      );
      expect(
        AppConfig.defaultReviewRelays.every(
          (String relay) => relay.startsWith('wss://'),
        ),
        isTrue,
      );
      expect(AppConfig.defaultBlossomServers, isNotEmpty);
      expect(
        AppConfig.defaultBlossomServers.every(
          (String server) => server.startsWith('https://'),
        ),
        isTrue,
      );
      expect(AppConfig.empty.reviewRelays, AppConfig.defaultReviewRelays);
      expect(AppConfig.empty.blossomServers, AppConfig.defaultBlossomServers);
    });

    test('the development Nostr key is debug-only', () {
      // `flutter test` runs in debug (non-product) mode.
      expect(AppConfig.isProductBuild, isFalse);
      // Honoured in a development build...
      expect(
        AppConfig.resolveNostrNsec(productBuild: false, raw: 'nsec1dev'),
        'nsec1dev',
      );
      // ...dropped in a release (product) build, so a baked-in define can never
      // auto-sign-in a production APK.
      expect(
        AppConfig.resolveNostrNsec(productBuild: true, raw: 'nsec1dev'),
        isEmpty,
      );
      expect(AppConfig.empty.hasNostrKey, isFalse);
      expect(const AppConfig(nostrNsec: 'nsec1dev').hasNostrKey, isTrue);
    });

    test('the update manifest URL defaults and can be overridden', () {
      expect(
        AppConfig.empty.updateManifestUrl,
        AppConfig.defaultUpdateManifestUrl,
      );
      expect(AppConfig.defaultUpdateManifestUrl, startsWith('https://'));
      const AppConfig custom = AppConfig(
        updateManifestUrl: 'https://updates.test/version.json',
      );
      expect(custom.updateManifestUrl, 'https://updates.test/version.json');
    });

    test('the Camelus service set has a key flag and camelus.app defaults', () {
      expect(AppConfig.empty.hasCamelusToken, isFalse);
      expect(
        const AppConfig(camelusApiToken: 'ck.test').hasCamelusToken,
        isTrue,
      );
      expect(const AppConfig(camelusApiToken: '  ').hasCamelusToken, isFalse);
      expect(
        AppConfig.defaultCamelusPhotonBaseUrl,
        'https://photon.map.camelus.app',
      );
      expect(
        AppConfig.defaultCamelusNominatimBaseUrl,
        'https://nominatim.map.camelus.app',
      );
      expect(
        AppConfig.defaultCamelusOverpassBaseUrl,
        'https://overpass.map.camelus.app/api',
      );
      expect(
        AppConfig.defaultCamelusValhallaBaseUrl,
        'https://valhalla.map.camelus.app',
      );
      expect(
        AppConfig.defaultCamelusTransitBaseUrl,
        'https://transit.map.camelus.app/api',
      );
      const AppConfig custom = AppConfig(
        camelusPhotonBaseUrl: 'https://photon.test',
      );
      expect(custom.camelusPhotonBaseUrl, 'https://photon.test');
    });
  });
}
