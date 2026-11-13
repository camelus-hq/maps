/// Compile-time configuration supplied via `--dart-define`
/// (or `--dart-define-from-file`).
///
/// Secrets never have defaults in source. With no defines the app runs
/// entirely on the in-memory fakes in `lib/data/fakes/`.
class AppConfig {
  const AppConfig({
    this.mapboxAccessToken = '',
    this.valhallaBaseUrl = '',
    this.mapStyleUrl = defaultMapStyleUrl,
    this.liveShareRelays = defaultLiveShareRelays,
    this.reviewRelays = defaultReviewRelays,
    this.blossomServers = defaultBlossomServers,
    this.photonBaseUrl = defaultPhotonBaseUrl,
    this.overpassBaseUrl = defaultOverpassBaseUrl,
    this.searchUserAgent = defaultSearchUserAgent,
    this.transitBaseUrl = defaultTransitBaseUrl,
    this.transitUserAgent = defaultTransitUserAgent,
    this.updateManifestUrl = defaultUpdateManifestUrl,
    this.feedbackPubkey = '',
    this.nostrNsec = '',
    this.camelusApiToken = '',
    this.camelusPhotonBaseUrl = defaultCamelusPhotonBaseUrl,
    this.camelusOverpassBaseUrl = defaultCamelusOverpassBaseUrl,
    this.camelusValhallaBaseUrl = defaultCamelusValhallaBaseUrl,
    this.camelusTransitBaseUrl = defaultCamelusTransitBaseUrl,
  });

  /// Mapbox style used until we ship our own (M2.3).
  static const String defaultMapStyleUrl = 'mapbox://styles/mapbox/standard';

  /// Relays the live-location share publishes and subscribes on.
  ///
  /// Live shares are NIP-59 gift-wrap encrypted to each selected friend, so a
  /// relay only ever sees an opaque, re-randomised envelope addressed to the
  /// recipient — never the sender, the content or the coordinates.
  ///
  /// Gift wraps are a special case for relays (many index/read relays refuse
  /// kind 1059 or demand NIP-42 auth for `#p` filters), so this is a small set
  /// of public relays that serve them: publishing to the users' own relay lists
  /// alone is not enough for two friends to meet. Override with
  /// `--dart-define=LIVE_SHARE_RELAYS=wss://a,wss://b`.
  static const List<String> defaultLiveShareRelays = <String>[
    'wss://relay.primal.net',
    'wss://relay.snort.social',
    'wss://relay.camelus.app',
    'wss://relay.map.camelus.app',
  ];

  /// Relays that carry public place reviews (kind 31987).
  ///
  /// Reviews are ordinary public events, so the same well-connected relays the
  /// live-share channel proved reachable are a good default; override with
  /// `--dart-define=REVIEW_RELAYS=wss://a,wss://b`.
  ///
  /// Verified live (2026-10-20): `relay.primal.net`, `relay.snort.social` and
  /// `nostr.mom` accept the write and serve the `#g`/`#d` reads for kind 31987;
  /// `relay.nos.social` answers `blocked: kind not allowed`, so it is not in
  /// the default set.
  static const List<String> defaultReviewRelays = <String>[
    'wss://relay.primal.net',
    'wss://relay.snort.social',
    'wss://nostr.mom',
    'wss://relay.map.camelus.app',
  ];

  /// Blossom servers review photos upload to (BUD-02). Public, free hosts by
  /// default; override with `--dart-define=BLOSSOM_SERVERS=https://a`.
  ///
  /// Verified live (2026-10-20, signed-in account, kind-24242 auth): primal,
  /// `nostr.download` and `files.sovbit.host` accept the upload; `blossom.band`
  /// and `blossom.nostr.build` answer 500 and `media.nostr.band` times out, so
  /// they are not defaults.
  static const List<String> defaultBlossomServers = <String>[
    'https://blossom.primal.net',
    'https://nostr.download',
  ];

  /// Base URL of **Photon** (`photon.komoot.io`), the key-less OpenStreetMap
  /// geocoder that powers OpenStreetMap search/autocomplete. Override with
  /// `--dart-define=SEARCH_PHOTON_URL=…`.
  static const String defaultPhotonBaseUrl = 'https://photon.komoot.io';

  /// Base URL of the **Overpass API** (`overpass-api.de/api`), the key-less
  /// OpenStreetMap query service that powers OpenStreetMap POI categories and
  /// the OSM element lookup behind the place sheet. Override with
  /// `--dart-define=SEARCH_OVERPASS_URL=…`.
  static const String defaultOverpassBaseUrl = 'https://overpass-api.de/api';

  /// `User-Agent` sent to Photon/Overpass. Both ask callers to identify
  /// themselves; set a contact (an e-mail or website) with
  /// `--dart-define=SEARCH_USER_AGENT=…` before a wider release.
  static const String defaultSearchUserAgent =
      'OpenMaps/0.1 (Flutter; OpenStreetMap search)';

  /// Base URL of the public-transport planner (Transitous, a community-run
  /// MOTIS 2 instance). Free and key-less; override with
  /// `--dart-define=TRANSIT_URL=…` to point at another MOTIS endpoint.
  static const String defaultTransitBaseUrl = 'https://api.transitous.org/api';

  /// `User-Agent` sent to the transit planner. Transitous' usage policy asks
  /// every caller to identify itself and to give a way to make contact (an
  /// e-mail or a website); set one with
  /// `--dart-define=TRANSIT_USER_AGENT=…` before any wider release.
  static const String defaultTransitUserAgent = 'OpenMaps/0.1 (Flutter)';

  /// The **Camelus** map services: Photon (search), Overpass (POI categories
  /// and OSM element lookup), Valhalla (routing) and MOTIS (public transport)
  /// behind one API key. Selected with the `camelus` search provider; every
  /// request carries the key as an `X-API-Key` header.
  ///
  /// Override each host with `--dart-define=CAMELUS_*_URL=…` and the key with
  /// `--dart-define=CAMELUS_MAP_API_TOKEN=…`.
  static const String defaultCamelusPhotonBaseUrl =
      'https://photon.map.camelus.app';
  static const String defaultCamelusOverpassBaseUrl =
      'https://overpass.map.camelus.app/api';
  static const String defaultCamelusValhallaBaseUrl =
      'https://valhalla.map.camelus.app';
  static const String defaultCamelusTransitBaseUrl =
      'https://transit.map.camelus.app/api';

  /// URL of the self-update manifest the app checks at startup. The release
  /// pipeline (`fastlane release`) writes this file and uploads the APK it
  /// points at; override with `--dart-define=UPDATE_MANIFEST_URL=…`.
  static const String defaultUpdateManifestUrl =
      'https://<example>/version.json';

  final String mapboxAccessToken;

  final String valhallaBaseUrl;

  final String mapStyleUrl;

  /// Relay URLs for the live-share channel.
  final List<String> liveShareRelays;

  /// Relay URLs that carry public reviews.
  final List<String> reviewRelays;

  /// Blossom servers review photos upload to.
  final List<String> blossomServers;

  /// Base URL of the OpenStreetMap geocoder used for search (Photon).
  final String photonBaseUrl;

  /// Base URL of the OpenStreetMap query service used for POI categories and
  /// the OSM element lookup (Overpass API).
  final String overpassBaseUrl;

  /// `User-Agent` sent to Photon/Overpass (see [defaultSearchUserAgent]).
  final String searchUserAgent;

  /// Base URL of the public-transport planner (Transitous/MOTIS).
  final String transitBaseUrl;

  /// `User-Agent` sent to the transit planner (see [defaultTransitUserAgent]).
  final String transitUserAgent;

  /// URL of the self-update manifest (see [defaultUpdateManifestUrl]).
  final String updateManifestUrl;

  /// The Nostr public key (`npub…` or 64-char hex) that in-app feedback is sent
  /// to, supplied with `--dart-define=FEEDBACK_PUBKEY=…`.
  ///
  /// Feedback leaves the app as a private (NIP-17 gift-wrapped) direct message
  /// with an AES-GCM-encrypted screenshot attached, so the recipient reads it in
  /// any NIP-17 client (Amethyst and friends). Empty disables sending: the alpha
  /// banner still opens the feedback screen, which then explains that this build
  /// has no recipient configured rather than silently doing nothing.
  final String feedbackPubkey;

  /// A Nostr private key (`nsec…`) supplied at build time
  /// (`--dart-define=NOSTR_NSEC=…`) so a **development** build signs in
  /// automatically instead of showing the login screen. Never committed.
  ///
  /// Always empty in a production (release) build: [fromEnvironment] drops the
  /// define unless this is a debug/profile build, so a release APK can never
  /// auto-sign-in with a baked-in key even if the define is left in the build
  /// command. See [isProductBuild] and [resolveNostrNsec].
  final String nostrNsec;

  /// API key for the **Camelus** map services (see
  /// [defaultCamelusPhotonBaseUrl]). Supplied with
  /// `--dart-define=CAMELUS_MAP_API_TOKEN=…`; never committed.
  final String camelusApiToken;

  /// Base URL of the Camelus Photon geocoder (search/autocomplete).
  final String camelusPhotonBaseUrl;

  /// Base URL of the Camelus Overpass API (POI categories and element lookup).
  final String camelusOverpassBaseUrl;

  /// Base URL of the Camelus Valhalla router.
  final String camelusValhallaBaseUrl;

  /// Base URL of the Camelus MOTIS public-transport planner.
  final String camelusTransitBaseUrl;

  bool get hasCamelusToken => camelusApiToken.trim().isNotEmpty;

  /// Whether feedback has a recipient configured (see [feedbackPubkey]).
  bool get hasFeedbackPubkey => feedbackPubkey.trim().isNotEmpty;

  bool get hasNostrKey => nostrNsec.trim().isNotEmpty;

  /// True for a release/AOT product build — the pure-Dart equivalent of
  /// Flutter's `kReleaseMode`, so `core/` stays free of Flutter imports.
  static const bool isProductBuild = bool.fromEnvironment('dart.vm.product');

  /// The automatic sign-in key to keep: [raw] in a development build, `''` in a
  /// release build. Pure so the "debug only" rule is unit-testable.
  static String resolveNostrNsec({
    required bool productBuild,
    required String raw,
  }) => productBuild ? '' : raw;

  bool get hasMapboxToken => mapboxAccessToken.isNotEmpty;

  bool get hasValhallaEndpoint => valhallaBaseUrl.isNotEmpty;

  static const AppConfig empty = AppConfig();

  factory AppConfig.fromEnvironment() => AppConfig(
    mapboxAccessToken: const String.fromEnvironment('MAPBOX_TOKEN'),
    valhallaBaseUrl: const String.fromEnvironment('VALHALLA_URL'),
    mapStyleUrl: const String.fromEnvironment(
      'MAP_STYLE_URL',
      defaultValue: defaultMapStyleUrl,
    ),
    liveShareRelays: _parseRelays(
      const String.fromEnvironment('LIVE_SHARE_RELAYS'),
    ),
    reviewRelays: _parseRelayList(
      const String.fromEnvironment('REVIEW_RELAYS'),
      defaultReviewRelays,
    ),
    blossomServers: _parseBlossomServers(
      const String.fromEnvironment('BLOSSOM_SERVERS'),
    ),
    photonBaseUrl: _httpBase(
      const String.fromEnvironment('SEARCH_PHOTON_URL'),
      defaultPhotonBaseUrl,
    ),
    overpassBaseUrl: _httpBase(
      const String.fromEnvironment('SEARCH_OVERPASS_URL'),
      defaultOverpassBaseUrl,
    ),
    searchUserAgent: _nonEmpty(
      const String.fromEnvironment('SEARCH_USER_AGENT'),
      defaultSearchUserAgent,
    ),
    transitBaseUrl: _httpBase(
      const String.fromEnvironment('TRANSIT_URL'),
      defaultTransitBaseUrl,
    ),
    transitUserAgent: _nonEmpty(
      const String.fromEnvironment('TRANSIT_USER_AGENT'),
      defaultTransitUserAgent,
    ),
    camelusApiToken: const String.fromEnvironment('CAMELUS_MAP_API_TOKEN'),
    camelusPhotonBaseUrl: _httpBase(
      const String.fromEnvironment('CAMELUS_PHOTON_URL'),
      defaultCamelusPhotonBaseUrl,
    ),
    camelusOverpassBaseUrl: _httpBase(
      const String.fromEnvironment('CAMELUS_OVERPASS_URL'),
      defaultCamelusOverpassBaseUrl,
    ),
    camelusValhallaBaseUrl: _httpBase(
      const String.fromEnvironment('CAMELUS_VALHALLA_URL'),
      defaultCamelusValhallaBaseUrl,
    ),
    camelusTransitBaseUrl: _httpBase(
      const String.fromEnvironment('CAMELUS_TRANSIT_URL'),
      defaultCamelusTransitBaseUrl,
    ),
    updateManifestUrl: _httpBase(
      const String.fromEnvironment('UPDATE_MANIFEST_URL'),
      defaultUpdateManifestUrl,
    ),
    feedbackPubkey: const String.fromEnvironment('FEEDBACK_PUBKEY').trim(),
    // Development-only convenience: the automatic sign-in key is compiled out
    // of a production build (a release APK never carries or uses it), so the
    // `NOSTR_NSEC` define is harmless if it is left in a release command.
    nostrNsec: resolveNostrNsec(
      productBuild: isProductBuild,
      raw: const String.fromEnvironment('NOSTR_NSEC'),
    ),
  );

  /// Splits a comma-separated relay list; empty means outbox routing.
  static List<String> _parseRelays(String raw) {
    final List<String> relays = <String>[
      for (final String part in raw.split(','))
        if (part.trim().startsWith('wss://') || part.trim().startsWith('ws://'))
          part.trim(),
    ];
    return relays.isEmpty ? defaultLiveShareRelays : relays;
  }

  /// Splits a comma-separated relay list, falling back to [fallback].
  static List<String> _parseRelayList(String raw, List<String> fallback) {
    final List<String> relays = <String>[
      for (final String part in raw.split(','))
        if (part.trim().startsWith('wss://') || part.trim().startsWith('ws://'))
          part.trim(),
    ];
    return relays.isEmpty ? fallback : relays;
  }

  /// Splits a comma-separated https Blossom server list, falling back to the
  /// public defaults.
  static List<String> _parseBlossomServers(String raw) {
    final List<String> servers = <String>[
      for (final String part in raw.split(','))
        if (part.trim().startsWith('https://') ||
            part.trim().startsWith('http://'))
          part.trim().replaceAll(RegExp(r'/+$'), ''),
    ];
    return servers.isEmpty ? defaultBlossomServers : servers;
  }

  /// A single http(s) base URL, or [fallback] when absent/invalid.
  static String _httpBase(String raw, String fallback) {
    final String value = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    return fallback;
  }

  /// A trimmed non-empty string, or [fallback].
  static String _nonEmpty(String raw, String fallback) {
    final String value = raw.trim();
    return value.isEmpty ? fallback : value;
  }
}
