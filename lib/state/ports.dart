import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fakes/fake_app_installer.dart';
import '../data/fakes/fake_app_version_source.dart';
import '../data/fakes/fake_external_actions.dart';
import '../data/fakes/fake_live_share_notifications.dart';
import '../data/fakes/fake_live_share_store.dart';
import '../data/fakes/fake_location_service.dart';
import '../data/fakes/fake_map_service.dart';
import '../data/fakes/fake_osm_place_source.dart';
import '../data/fakes/fake_places_repository.dart';
import '../data/fakes/fake_release_source.dart';
import '../data/fakes/fake_review_service.dart';
import '../data/fakes/fake_routing_service.dart';
import '../data/fakes/fake_search_service.dart';
import '../data/fakes/fake_settings_repository.dart';
import '../data/fakes/fake_social_service.dart';
import '../data/fakes/fake_transit_routing_service.dart';
import '../domain/ports/app_installer.dart';
import '../domain/ports/app_version_source.dart';
import '../domain/ports/external_actions.dart';
import '../domain/ports/live_share_notifications.dart';
import '../domain/ports/live_share_store.dart';
import '../domain/ports/location_service.dart';
import '../domain/ports/map_service.dart';
import '../domain/ports/osm_place_source.dart';
import '../domain/ports/places_repository.dart';
import '../domain/ports/release_source.dart';
import '../domain/ports/review_service.dart';
import '../domain/ports/routing_service.dart';
import '../domain/ports/search_service.dart';
import '../domain/ports/settings_repository.dart';
import '../domain/ports/social_service.dart';
import '../domain/ports/transit_routing_service.dart';

/// Port providers.
///
/// Defaults are keyless in-memory fakes so the app always runs. `lib/app/di.dart`
/// overrides them with real adapters (Mapbox/Valhalla/…) when configured; tests
/// override them with fakes or stubs. No widget or notifier changes when a
/// backend changes.
final Provider<MapService> mapServiceProvider = Provider<MapService>((Ref ref) {
  final FakeMapService service = FakeMapService();
  ref.onDispose(service.dispose);
  return service;
});

final Provider<RoutingService> routingServiceProvider =
    Provider<RoutingService>((Ref ref) => const FakeRoutingService());

/// Public-transport journeys (Transitous/MOTIS behind the port). The keyless
/// default is a deterministic in-memory fake; `lib/app/di.dart` swaps in the
/// real planner. Swapping the provider is a one-line change here.
final Provider<TransitRoutingService> transitRoutingServiceProvider =
    Provider<TransitRoutingService>((Ref ref) => FakeTransitRoutingService());

final Provider<SearchService> searchServiceProvider = Provider<SearchService>(
  (Ref ref) => const FakeSearchService(),
);

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) => const FakeLocationService());

final Provider<PlacesRepository> placesRepositoryProvider =
    Provider<PlacesRepository>((Ref ref) => FakePlacesRepository());

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) => FakeSettingsRepository());

final Provider<SocialService> socialServiceProvider = Provider<SocialService>((
  Ref ref,
) {
  // The keyless default starts signed in as a demo identity but with nobody
  // live — an honest empty state. `social.simulate.friendLocation` (below) or
  // a real share fills it in.
  final FakeSocialService service = FakeSocialService();
  ref.onDispose(service.dispose);
  return service;
});

final Provider<LiveShareStore> liveShareStoreProvider =
    Provider<LiveShareStore>((Ref ref) => FakeLiveShareStore());

/// Place reviews (Nostr kind 31987) and Blossom photo uploads. The keyless
/// default is a seeded in-memory fake; `lib/app/di.dart` swaps in the NDK
/// adapter when a Nostr client is available.
final Provider<ReviewService> reviewServiceProvider = Provider<ReviewService>(
  (Ref ref) => FakeReviewService(),
);

/// OpenStreetMap element lookup, used to put a real name on a place we only
/// know from a review's key. The keyless default resolves nothing (the app
/// falls back to the raw reference); `lib/app/di.dart` wires the real lookup.
final Provider<OsmPlaceSource> osmPlaceSourceProvider =
    Provider<OsmPlaceSource>((Ref ref) => FakeOsmPlaceSource());

final Provider<LiveShareNotifications> liveShareNotificationsProvider =
    Provider<LiveShareNotifications>((Ref ref) => FakeLiveShareNotifications());

/// Opens the device's own apps for a place's contact details (dial, e-mail,
/// website). The keyless/test default records the request instead of leaving
/// the app; `lib/app/di.dart` wires the real launcher.
final Provider<ExternalActions> externalActionsProvider =
    Provider<ExternalActions>((Ref ref) => FakeExternalActions());

/// Reads the installed app version (platform package metadata). The keyless
/// default reports a fixed version; `lib/app/di.dart` wires `package_info_plus`.
final Provider<AppVersionSource> appVersionSourceProvider =
    Provider<AppVersionSource>((Ref ref) => FakeAppVersionSource());

/// Fetches the latest release from the update manifest. The keyless default
/// advertises **no** release, so no prompt appears without configuration;
/// `lib/app/di.dart` wires the HTTP manifest.
final Provider<ReleaseSource> releaseSourceProvider = Provider<ReleaseSource>(
  (Ref ref) => FakeReleaseSource(),
);

/// Downloads and installs a release APK. The keyless/test default records the
/// request instead of installing; `lib/app/di.dart` wires the Android installer.
final Provider<AppInstaller> appInstallerProvider = Provider<AppInstaller>(
  (Ref ref) => FakeAppInstaller(),
);
