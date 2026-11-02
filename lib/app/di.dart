import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../core/config/app_config.dart';
import '../data/http/api_key_client.dart';
import '../data/local/prefs_live_share_store.dart';
import '../data/local/prefs_places_repository.dart';
import '../data/local/prefs_settings_repository.dart';
import '../data/location/geolocator_location_service.dart';
import '../data/mapbox/mapbox_map_service.dart';
import '../data/mapbox/mapbox_map_view.dart';
import '../data/mapbox/mapbox_search_service.dart';
import '../data/nostr/ndk_review_service.dart';
import '../data/nostr/ndk_social_service.dart';
import '../data/notifications/local_live_share_notifications.dart';
import '../data/osm/nominatim_place_source.dart';
import '../data/osm/osm_search_service.dart';
import '../data/platform/url_launcher_external_actions.dart';
import '../data/transitous/transitous_transit_routing_service.dart';
import '../data/update/android_app_installer.dart';
import '../data/update/http_release_source.dart';
import '../data/update/package_info_app_version_source.dart';
import '../data/valhalla/valhalla_routing_service.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/ports/search_service.dart';
import '../state/config.dart';
import '../state/map_view.dart';
import '../state/ports.dart';
import '../state/settings.dart';
import '../state/social.dart';

/// Default map camera target (neutral area) until a real fix/style arrives.
const Camera _defaultCamera = Camera(target: LatLon(52.52, 13.405));

/// Builds the [ProviderScope] overrides that select real backends.
///
/// With no `--dart-define` secrets everything runs on the keyless fakes in
/// `lib/state/ports.dart`. The map adapter is wired when a Mapbox token is
/// present; search follows the setting (Mapbox token or key-less OpenStreetMap);
/// Valhalla joins in M4. [ndk] and [ndkFlutter] are created once at bootstrap
/// and wire the live-share backend.
List<Override> buildAppOverrides(
  AppConfig config, {
  Ndk? ndk,
  NdkFlutter? ndkFlutter,
}) {
  final List<Override> overrides = <Override>[
    appConfigProvider.overrideWithValue(config),
    // Local persistence is always available (recent searches, bookmarks).
    placesRepositoryProvider.overrideWith((Ref ref) => PrefsPlacesRepository()),
    settingsRepositoryProvider.overrideWith(
      (Ref ref) => PrefsSettingsRepository(),
    ),
    // Live location: the outgoing-session store and the ongoing notification.
    liveShareStoreProvider.overrideWith((Ref ref) => PrefsLiveShareStore()),
    liveShareNotificationsProvider.overrideWith(
      (Ref ref) => LocalLiveShareNotifications(),
    ),
    // Device location (GNSS) behind the port; degrades gracefully without
    // permission, so keyless/test runs still use the fake default.
    locationServiceProvider.overrideWith(
      (Ref ref) => GeolocatorLocationService(),
    ),
    // OpenStreetMap element lookup (Nominatim). Public HTTP with no key by
    // default; with the Camelus provider selected it points at
    // `nominatim.map.camelus.app` and carries the API key. Requests are cached
    // and spaced per the public policy.
    osmPlaceSourceProvider.overrideWith((Ref ref) {
      final bool camelus = _camelusSelected(ref, config);
      return NominatimPlaceSource(
        client: _httpClient(ref, apiKey: camelus ? config.camelusApiToken : ''),
        baseUrl: camelus ? config.camelusNominatimBaseUrl : config.osmBaseUrl,
        minInterval: const Duration(seconds: 1),
      );
    }),
    // Handing a place's contact details to the device (dial / e-mail / website).
    // No key, so it is wired for every build.
    externalActionsProvider.overrideWith(
      (Ref ref) => const UrlLauncherExternalActions(),
    ),
    // Search runs on whichever backend the user picked in settings. All
    // adapters sit behind the same port, so the choice is one provider rebuild;
    // OpenStreetMap (Photon + Overpass) needs no key, so it stays available
    // even without a Mapbox or Camelus token.
    searchServiceProvider.overrideWith(
      (Ref ref) => buildSearchService(ref, config),
    ),
    // Public-transport planning (MOTIS). Transitous by default (a key-less
    // community instance); with the Camelus provider selected it points at
    // `transit.map.camelus.app` and carries the API key.
    transitRoutingServiceProvider.overrideWith((Ref ref) {
      final bool camelus = _camelusSelected(ref, config);
      return TransitousTransitRoutingService(
        client: _httpClient(ref, apiKey: camelus ? config.camelusApiToken : ''),
        baseUrl: camelus ? config.camelusTransitBaseUrl : config.transitBaseUrl,
        userAgent: config.transitUserAgent,
      );
    }),
    // Self-update: the installed version comes from the platform metadata, the
    // release from the published JSON manifest, and the install from the
    // Android installer. Key-less, so it is wired for every build.
    appVersionSourceProvider.overrideWith(
      (Ref ref) => const PackageInfoAppVersionSource(),
    ),
    releaseSourceProvider.overrideWith((Ref ref) {
      final http.Client client = http.Client();
      ref.onDispose(client.close);
      return HttpReleaseSource(
        client: client,
        manifestUrl: config.updateManifestUrl,
      );
    }),
    appInstallerProvider.overrideWith((Ref ref) {
      final http.Client client = http.Client();
      ref.onDispose(client.close);
      return AndroidAppInstaller(client: client);
    }),
  ];

  if (ndk != null && ndkFlutter != null) {
    final NdkSocialService social = NdkSocialService(
      ndk: ndk,
      ndkFlutter: ndkFlutter,
      relays: config.liveShareRelays,
    );
    final NdkReviewService reviews = NdkReviewService(
      ndk: ndk,
      relays: config.reviewRelays,
      blossomServers: config.blossomServers,
    );
    overrides
      ..add(
        socialServiceProvider.overrideWith((Ref ref) {
          ref.onDispose(() => unawaited(social.dispose()));
          return social;
        }),
      )
      ..add(reviewServiceProvider.overrideWithValue(reviews))
      ..add(ndkFlutterProvider.overrideWithValue(ndkFlutter));
  }

  if (config.hasMapboxToken) {
    final MapboxMapService mapService = MapboxMapService(
      accessToken: config.mapboxAccessToken,
      styleUri: config.mapStyleUrl,
      initialCamera: _defaultCamera,
    );
    unawaited(mapService.initialize());
    overrides
      ..add(
        mapServiceProvider.overrideWith((Ref ref) {
          ref.onDispose(mapService.dispose);
          return mapService;
        }),
      )
      ..add(
        mapViewBuilderProvider.overrideWithValue(
          (BuildContext context) => MapboxMapView(service: mapService),
        ),
      );
  }

  // Valhalla is wired when a `VALHALLA_URL` is configured, or via the Camelus
  // provider (which bundles a Valhalla router behind the API key).
  if (config.hasValhallaEndpoint || config.hasCamelusToken) {
    overrides.add(
      routingServiceProvider.overrideWith((Ref ref) {
        final bool camelus = _camelusSelected(ref, config);
        return ValhallaRoutingService(
          client: _httpClient(
            ref,
            apiKey: camelus ? config.camelusApiToken : '',
          ),
          baseUrl: camelus
              ? config.camelusValhallaBaseUrl
              : config.valhallaBaseUrl,
        );
      }),
    );
  }

  return overrides;
}

/// Whether the Camelus service set is selected **and** has a key, so callers
/// only redirect to `*.map.camelus.app` when it can actually authenticate.
bool _camelusSelected(Ref ref, AppConfig config) =>
    config.hasCamelusToken &&
    ref.watch(searchBackendProvider) == SearchBackend.camelus;

/// An `http.Client`, wrapped to carry the API key when [apiKey] is set. The
/// wrapper is disposed with the provider that created it.
http.Client _httpClient(Ref ref, {String apiKey = ''}) {
  final http.Client inner = http.Client();
  ref.onDispose(inner.close);
  return apiKey.isEmpty ? inner : ApiKeyClient(inner, apiKey: apiKey);
}

/// Builds the [SearchService] for the backend selected in settings.
///
/// [SearchBackend.mapbox] needs an access token and [SearchBackend.camelus]
/// needs an API key: without one the choice falls back to OpenStreetMap
/// (Photon + Overpass), which is key-less, so search keeps working in a
/// token-less development run. The provider rebuilds when the setting changes,
/// so switching takes effect on the next query with no restart and no widget
/// changes.
SearchService buildSearchService(Ref ref, AppConfig config) {
  final SearchBackend requested = ref.watch(searchBackendProvider);
  final SearchBackend backend = switch (requested) {
    SearchBackend.mapbox when !config.hasMapboxToken =>
      SearchBackend.openstreetmap,
    SearchBackend.camelus when !config.hasCamelusToken =>
      SearchBackend.openstreetmap,
    _ => requested,
  };

  switch (backend) {
    case SearchBackend.mapbox:
      return MapboxSearchService(
        client: _httpClient(ref),
        accessToken: config.mapboxAccessToken,
      );
    case SearchBackend.camelus:
      // The Camelus service set: Photon + Overpass here, and the same host/key
      // drives routing, transit and place lookup (see `buildAppOverrides`).
      return OsmSearchService(
        client: _httpClient(ref, apiKey: config.camelusApiToken),
        photonBaseUrl: config.camelusPhotonBaseUrl,
        overpassBaseUrl: config.camelusOverpassBaseUrl,
        userAgent: config.searchUserAgent,
      );
    case SearchBackend.openstreetmap:
      return OsmSearchService(
        client: _httpClient(ref),
        photonBaseUrl: config.photonBaseUrl,
        overpassBaseUrl: config.overpassBaseUrl,
        userAgent: config.searchUserAgent,
      );
  }
}
