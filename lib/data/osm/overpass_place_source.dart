import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/utils/osm_ref.dart';
import '../../domain/entities/place.dart';
import '../../domain/ports/osm_place_source.dart';
import '../dto/overpass_place_mapper.dart';

/// [OsmPlaceSource] backed by the Overpass API (OpenStreetMap data).
///
/// Fetches a single element by its OSM id and returns the element's whole tag
/// set, so the place sheet sees the real name and address plus the contact,
/// accessibility, opening-hours, payment and image tags. One element per call,
/// so it is a light, deliberate request: results are cached, requests are spaced
/// by [minInterval], and a slow or hostile response degrades to a typed
/// [AppException] rather than a crash.
class OverpassPlaceSource implements OsmPlaceSource {
  OverpassPlaceSource({
    required this.client,
    this.baseUrl = defaultBaseUrl,
    this.userAgent = defaultUserAgent,
    this.minInterval = Duration.zero,
    this.timeout = const Duration(seconds: 8),
    this.maxCache = 200,
  });

  static const String defaultBaseUrl = 'https://overpass-api.de/api';

  /// Overpass' usage policy asks every caller to identify itself.
  static const String defaultUserAgent =
      'OpenMaps/0.1 (Flutter; OSM element lookup)';

  final http.Client client;
  final String baseUrl;
  final String userAgent;

  /// Minimum gap between two requests (set to one second in the app).
  final Duration minInterval;

  final Duration timeout;

  /// How many lookups to remember (a miss is cached too).
  final int maxCache;

  final Map<String, Place?> _cache = <String, Place?>{};
  DateTime? _lastRequest;

  @override
  Future<Place?> lookup(String osmRef) async {
    final (String, int)? ref = _parse(osmRef);
    if (ref == null) {
      return null;
    }
    final String key = '${ref.$1}/${ref.$2}';
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    await _throttle();
    final Uri uri = Uri.parse('$baseUrl/interpreter');

    final http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: <String, String>{
              'User-Agent': userAgent,
              'Accept': 'application/json',
            },
            body: <String, String>{'data': _query(ref.$1, ref.$2)},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RequestTimeoutException(
        'Looking up this place took too long',
      );
    } catch (error) {
      throw NetworkException('Could not look up this place', cause: error);
    }
    if (response.statusCode != 200) {
      throw NetworkException(
        'Could not look up this place (HTTP ${response.statusCode})',
      );
    }

    final Place? place = _parseBody(response.body, key);
    _remember(key, place);
    return place;
  }

  /// The Overpass QL that fetches the element by id. [type] comes from a
  /// validated `OsmRef` (`node`/`way`/`relation`) and [id] is a positive
  /// integer, so interpolating them is safe.
  static String _query(String type, int id) =>
      '[out:json][timeout:25];$type($id);out center;';

  Future<void> _throttle() async {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastRequest;
    if (last != null && minInterval > Duration.zero) {
      final Duration wait = minInterval - now.difference(last);
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
    _lastRequest = DateTime.now();
  }

  void _remember(String key, Place? place) {
    _cache[key] = place;
    while (_cache.length > maxCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Parses the Overpass body (`{"elements":[…]}`) into the element named by
  /// [key], or `null` when it is absent. Every field is treated as hostile.
  Place? _parseBody(String body, String key) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const ValidationException('The place lookup returned invalid data');
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    // Overpass answers an error object (`{"remark": …}`) with no elements.
    final Object? remark = decoded['remark'];
    if (remark is String && remark.trim().isNotEmpty) {
      final String message = remark.trim();
      throw NetworkException(
        'Overpass: '
        '${message.length > 200 ? message.substring(0, 200) : message}',
      );
    }
    final Object? elements = decoded['elements'];
    if (elements is! List<Object?>) {
      return null;
    }
    for (final Object? element in elements) {
      final Place? place = OverpassPlaceMapper.fromElement(
        element,
        fallbackName: key,
      );
      // A by-id query answers at most one element; ignore any other so a stray
      // entry can never be shown under the requested place.
      if (place != null && place.id == key) {
        return place;
      }
    }
    return null;
  }

  /// Splits an OSM reference (`way/123`) into its type and id, or `null` when it
  /// is not a positive OSM element reference.
  static (String, int)? _parse(String raw) {
    final String value = raw.trim();
    if (!OsmRef.isRef(value)) {
      return null;
    }
    final int slash = value.indexOf('/');
    final String type = value.substring(0, slash).toLowerCase();
    final int? id = int.tryParse(value.substring(slash + 1));
    if (id == null || id <= 0) {
      return null;
    }
    return (type, id);
  }
}
