import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/lat_lon_bounds.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/place_category.dart';
import '../../domain/ports/search_service.dart';
import '../dto/mapbox_geocoding_mapper.dart';
import '../dto/mapbox_search_box_mapper.dart';

/// [SearchService] backed by the Mapbox Geocoding v5 API.
///
/// Hostile-safe: non-2xx and malformed bodies raise typed [AppException]s and
/// bad features are dropped by [MapboxGeocodingMapper].
class MapboxSearchService implements SearchService {
  MapboxSearchService({
    required this.client,
    required this.accessToken,
    this.baseUrl = defaultBaseUrl,
    this.searchBoxBaseUrl = defaultSearchBoxBaseUrl,
  });

  static const String defaultBaseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String defaultSearchBoxBaseUrl =
      'https://api.mapbox.com/search/searchbox/v1';
  static const int _limit = 10;
  static const Duration _timeout = Duration(seconds: 8);

  final http.Client client;
  final String accessToken;
  final String baseUrl;
  final String searchBoxBaseUrl;

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
    final Uri uri = Uri.parse('$baseUrl/${Uri.encodeComponent(trimmed)}.json')
        .replace(
          queryParameters: <String, String>{
            'access_token': accessToken,
            'limit': '$_limit',
            'types': 'poi,address,place,locality,neighborhood',
            'language': 'en',
            if (proximity != null)
              'proximity': '${proximity.longitude},${proximity.latitude}',
            // Mapbox bbox order is minLon,minLat,maxLon,maxLat.
            if (bounds != null)
              'bbox':
                  '${bounds.west},${bounds.south},'
                  '${bounds.east},${bounds.north}',
          },
        );

    final http.Response response;
    try {
      response = await client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const RequestTimeoutException('Geocoding request timed out');
    } on http.ClientException catch (error) {
      // No connection / DNS failure / connection dropped: treat as offline.
      throw OfflineException('Geocoding request failed', cause: error);
    } catch (error) {
      throw NetworkException('Geocoding request failed', cause: error);
    }

    if (response.statusCode != 200) {
      throw NetworkException('Geocoding failed (HTTP ${response.statusCode})');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ValidationException('Malformed geocoding response');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ValidationException('Unexpected geocoding response shape');
    }
    final Object? features = decoded['features'];
    if (features is! List<Object?>) {
      return const <Place>[];
    }

    final List<Place> places = <Place>[];
    for (final Object? feature in features) {
      final Place? place = MapboxGeocodingMapper.fromFeature(feature);
      if (place != null) {
        places.add(place);
      }
      if (places.length >= _limit) {
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
    // Mapbox only has an index for a subset of our categories; for the rest the
    // caller falls back to a bounded free-text search rather than drawing an
    // empty result set as "no places here".
    final String? mapboxId = placeCategoryById(categoryId)?.mapboxId;
    if (mapboxId == null) {
      throw UnsupportedException('No Mapbox category for "$categoryId"');
    }
    final Uri uri =
        Uri.parse('$searchBoxBaseUrl/category/${Uri.encodeComponent(mapboxId)}')
            .replace(
              queryParameters: <String, String>{
                'access_token': accessToken,
                'limit': '$limit',
                'language': 'en',
                'proximity': '${proximity.longitude},${proximity.latitude}',
              },
            );

    final http.Response response;
    try {
      response = await client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const RequestTimeoutException('Category search timed out');
    } on http.ClientException catch (error) {
      throw OfflineException('Category search failed', cause: error);
    } catch (error) {
      throw NetworkException('Category search failed', cause: error);
    }
    if (response.statusCode != 200) {
      throw NetworkException(
        'Category search failed (HTTP ${response.statusCode})',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ValidationException('Malformed category response');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ValidationException('Unexpected category response shape');
    }
    final Object? features = decoded['features'];
    if (features is! List<Object?>) {
      return const <Place>[];
    }
    final List<Place> places = <Place>[];
    for (final Object? feature in features) {
      final Place? place = MapboxSearchBoxMapper.fromFeature(feature);
      // The Search Box category endpoint has no bounding-box parameter, so a
      // viewport limit is enforced here: results outside it are dropped.
      if (place != null &&
          (bounds == null || bounds.contains(place.position))) {
        places.add(place);
      }
      if (places.length >= limit) {
        break;
      }
    }
    return List<Place>.unmodifiable(places);
  }
}
