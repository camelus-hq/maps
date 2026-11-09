import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/lat_lon_bounds.dart';
import '../../domain/entities/place.dart';
import '../../domain/ports/search_service.dart';
import '../dto/overpass_place_mapper.dart';
import '../dto/photon_place_mapper.dart';
import 'osm_category_filter.dart';

/// [SearchService] backed by OpenStreetMap's community services:
///
/// * **Photon** (`photon.komoot.io`) for free-text search and autocomplete — a
///   key-less, fast type-ahead geocoder over OSM data.
/// * **Overpass API** (`overpass-api.de`) for "near me" POI category browse,
///   which Photon has no category index for.
///
/// Both are public, key-less and rate-limited by their operators, so requests
/// carry a descriptive `User-Agent` and a bounded timeout, and every hostile
/// response becomes a typed [AppException] rather than a crash (AGENTS.md
/// "Never crash"). Results are OpenStreetMap elements, so their ids are
/// canonical `node/…` / `way/…` / `relation/…` references the place sheet can
/// enrich through the Overpass element lookup.
class OsmSearchService implements SearchService {
  OsmSearchService({
    required this.client,
    this.photonBaseUrl = defaultPhotonBaseUrl,
    this.overpassBaseUrl = defaultOverpassBaseUrl,
    this.userAgent = defaultUserAgent,
    this.searchTimeout = const Duration(seconds: 8),
    this.categoryTimeout = const Duration(seconds: 30),
  });

  static const String defaultPhotonBaseUrl = 'https://photon.komoot.io';
  static const String defaultOverpassBaseUrl = 'https://overpass-api.de/api';

  /// Photon/Overpass' usage policies ask callers to identify themselves.
  static const String defaultUserAgent =
      'OpenMaps/0.1 (Flutter; OpenStreetMap search)';

  static const int _searchLimit = 10;

  /// How many POIs the Overpass query is allowed to yield before we sort by
  /// distance and trim to the requested `limit`.
  static const int _poiScanLimit = 200;

  /// Fallback search radius for a category browse when no bounding box is
  /// supplied (metres). Kept under a kilometre so a bare `nearbyCategory` call
  /// can never query a huge area.
  static const int _categoryRadiusMeters = 800;

  final http.Client client;
  final String photonBaseUrl;
  final String overpassBaseUrl;
  final String userAgent;
  final Duration searchTimeout;
  final Duration categoryTimeout;

  @override
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <Place>[];
    }
    final Uri uri = Uri.parse('$photonBaseUrl/api').replace(
      queryParameters: <String, String>{
        'q': trimmed,
        'limit': '$_searchLimit',
        'lang': 'en',
        if (proximity != null) 'lat': '${proximity.latitude}',
        if (proximity != null) 'lon': '${proximity.longitude}',
        // Photon's bbox order is minLon,minLat,maxLon,maxLat.
        if (bounds != null)
          'bbox':
              '${bounds.west},${bounds.south},'
              '${bounds.east},${bounds.north}',
      },
    );

    final String body = await _send(
      () => client.get(uri, headers: _headers),
      timeout: searchTimeout,
      what: 'Search',
    );
    final Object? decoded = _decode(body, 'search');
    // Photon answers a GeoJSON FeatureCollection.
    final Object? features = decoded is Map<String, Object?>
        ? decoded['features']
        : null;
    if (features is! List<Object?>) {
      throw const ValidationException('Unexpected search response shape');
    }

    final List<Place> places = <Place>[];
    for (final Object? feature in features) {
      final Place? place = PhotonPlaceMapper.fromFeature(feature);
      if (place != null) {
        places.add(place);
      }
      if (places.length >= _searchLimit) {
        break;
      }
    }
    return List<Place>.unmodifiable(places);
  }

  @override
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  }) async {
    final String? filter = OsmCategoryFilter.forCategory(categoryId);
    if (filter == null) {
      // No POI index for this category in OpenStreetMap; the caller falls back
      // to a free-text search.
      throw UnsupportedException('No OpenStreetMap category for "$categoryId"');
    }
    final String overpassQuery = _overpassQuery(filter, proximity, bounds);
    final Uri uri = Uri.parse('$overpassBaseUrl/interpreter');

    final String body = await _send(
      () => client.post(
        uri,
        headers: _headers,
        body: <String, String>{'data': overpassQuery},
      ),
      timeout: categoryTimeout,
      what: 'Category search',
    );
    final Object? decoded = _decode(body, 'category');
    if (decoded is! Map<String, Object?>) {
      throw const ValidationException('Unexpected category response shape');
    }
    final Object? elements = decoded['elements'];
    if (elements is! List<Object?>) {
      // Overpass answers an error object (`{"remark": …}`) with no elements.
      final String? remark = switch (decoded['remark']) {
        final String value when value.trim().isNotEmpty => value.trim(),
        _ => null,
      };
      if (remark != null) {
        throw NetworkException(
          'Overpass: ${remark.length > 200 ? remark.substring(0, 200) : remark}',
        );
      }
      return const <Place>[];
    }

    // Sort the scanned POIs by distance from the browse centre and trim, so the
    // nearest places come back regardless of Overpass' element order.
    final List<Place> found = <Place>[];
    for (final Object? element in elements) {
      final Place? place = OverpassPlaceMapper.fromElement(element);
      if (place != null) {
        found.add(place);
      }
      if (found.length >= _poiScanLimit) {
        break;
      }
    }
    found.sort(
      (Place a, Place b) => a.position
          .distanceTo(proximity)
          .compareTo(b.position.distanceTo(proximity)),
    );
    final int capped = limit < 0 ? 0 : limit;
    return List<Place>.unmodifiable(found.take(capped));
  }

  /// Builds the Overpass QL for a POI category filter.
  ///
  /// With [bounds] the query is limited to that viewport rectangle — Overpass'
  /// own bounding-box filter `(south,west,north,east)` — so only what is on
  /// screen comes back. Without one it falls back to a small `around:` radius
  /// around [center].
  ///
  /// The filter comes from our own fixed table ([OsmCategoryFilter]), never
  /// from user input, so it is safe to interpolate; coordinates are formatted
  /// as plain numbers.
  static String _overpassQuery(
    String filter,
    LatLon center,
    LatLonBounds? bounds,
  ) {
    final String area = bounds == null
        ? 'around:$_categoryRadiusMeters,'
              '${center.latitude.toStringAsFixed(6)},'
              '${center.longitude.toStringAsFixed(6)}'
        : '${bounds.south.toStringAsFixed(6)},'
              '${bounds.west.toStringAsFixed(6)},'
              '${bounds.north.toStringAsFixed(6)},'
              '${bounds.east.toStringAsFixed(6)}';
    return '[out:json][timeout:20];'
        '('
        'node[$filter]($area);'
        'way[$filter]($area);'
        'relation[$filter]($area);'
        ');'
        'out center;';
  }

  Map<String, String> get _headers => <String, String>{
    'User-Agent': userAgent,
    'Accept': 'application/json',
  };

  /// Runs [request] with a bounded timeout, mapping transport failures onto the
  /// typed [AppException] family (offline, timeout, non-2xx).
  Future<String> _send(
    Future<http.Response> Function() request, {
    required Duration timeout,
    required String what,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw RequestTimeoutException('$what took too long');
    } on http.ClientException catch (error) {
      // No connection / DNS failure / connection dropped: treat as offline.
      throw OfflineException('$what failed', cause: error);
    } catch (error) {
      throw NetworkException('$what failed', cause: error);
    }
    if (response.statusCode != 200) {
      throw NetworkException('$what failed (HTTP ${response.statusCode})');
    }
    return response.body;
  }

  Object? _decode(String body, String what) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ValidationException('Malformed $what response');
    }
  }
}
