import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/utils/osm_ref.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';
import '../../domain/ports/osm_place_source.dart';

/// [OsmPlaceSource] backed by Nominatim's `lookup` endpoint (OpenStreetMap data).
///
/// One element per call, so it is a light, deliberate request: results are
/// cached, requests are spaced by [minInterval] (Nominatim's policy asks for at
/// most one per second and a descriptive User-Agent), and a slow or hostile
/// response degrades to a typed [AppException] rather than a crash.
class NominatimPlaceSource implements OsmPlaceSource {
  NominatimPlaceSource({
    required this.client,
    this.baseUrl = defaultBaseUrl,
    this.minInterval = Duration.zero,
    this.timeout = const Duration(seconds: 8),
    this.maxCache = 200,
  });

  static const String defaultBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Nominatim asks every caller to identify itself.
  static const String userAgent = 'OpenMaps/0.1 (Flutter; review place lookup)';

  final http.Client client;
  final String baseUrl;

  /// Minimum gap between two requests (set to one second in the app).
  final Duration minInterval;

  final Duration timeout;

  /// How many lookups to remember (a miss is cached too).
  final int maxCache;

  final Map<String, Place?> _cache = <String, Place?>{};
  DateTime? _lastRequest;

  @override
  Future<Place?> lookup(String osmRef) async {
    final _Ref? ref = _Ref.parse(osmRef);
    if (ref == null) {
      return null;
    }
    if (_cache.containsKey(ref.ref)) {
      return _cache[ref.ref];
    }
    await _throttle();
    final Uri uri = Uri.parse('$baseUrl/lookup').replace(
      queryParameters: <String, String>{
        'osm_ids': ref.nominatimId,
        'format': 'jsonv2',
        'addressdetails': '1',
        'namedetails': '1',
        // The contact/accessibility tags the place sheet shows (`contact:phone`,
        // `contact:email`, `wheelchair`, `opening_hours`, …) only arrive with
        // `extratags`.
        'extratags': '1',
        'accept-language': 'en',
      },
    );

    final http.Response response;
    try {
      response = await client
          .get(
            uri,
            headers: <String, String>{
              'User-Agent': userAgent,
              'Accept': 'application/json',
            },
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

    final Place? place = _parse(response.body, ref);
    _remember(ref.ref, place);
    return place;
  }

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

  /// Parses the `lookup` body (a JSON array with at most one element) into a
  /// [Place]. Every field is treated as hostile.
  Place? _parse(String body, _Ref ref) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const ValidationException('The place lookup returned invalid data');
    }
    if (decoded is! List<Object?>) {
      // Nominatim answers an error object (`{"error": …}`) for a bad request.
      return null;
    }
    for (final Object? entry in decoded) {
      final Place? place = _placeFromEntry(entry, ref);
      if (place != null) {
        return place;
      }
    }
    return null;
  }

  Place? _placeFromEntry(Object? raw, _Ref ref) {
    if (raw is! Map) {
      return null;
    }
    final LatLon? position = LatLon.tryParse(raw['lat'], raw['lon']);
    if (position == null) {
      return null;
    }
    final String? displayName = _string(raw['display_name'], 300);
    final String? name =
        _string(raw['name'], 120) ??
        _firstSegment(displayName) ??
        _addressFallback(raw['address']);
    final String? category =
        _string(raw['type'], 60) ?? _string(raw['category'], 60);
    final Map<Object?, Object?>? extra = raw['extratags'] is Map
        ? (raw['extratags']! as Map).cast<Object?, Object?>()
        : null;
    return Place(
      id: ref.ref,
      name: name ?? ref.ref,
      position: position,
      category: category,
      address: displayName,
      email: _contact(extra, const <String>['contact:email', 'email'], 254),
      phone: _contact(extra, const <String>[
        'contact:phone',
        'phone',
        'contact:mobile',
        'mobile',
      ], 40),
      website: _contact(extra, const <String>[
        'contact:website',
        'website',
        'url',
      ], 300),
      wheelchairAccessible: _wheelchair(extra),
      openingHours: _contact(extra, const <String>['opening_hours'], 200),
      osmTags: _tags(extra),
    );
  }

  /// Every `extratags` entry, bounded and trimmed. On the main Nominatim instance
  /// `extratags` carries the element's remaining OSM tags (`payment:*`, `image`,
  /// `takeaway`, `description:*`, …), which the developer "show all tags" view and
  /// the payment/photos readers consume. Extra tags are attacker-controlled.
  static Map<String, String> _tags(Map<Object?, Object?>? extra) {
    if (extra == null || extra.isEmpty) {
      return const <String, String>{};
    }
    final Map<String, String> tags = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in extra.entries) {
      final String? key = _string(entry.key, 100);
      final String? value = _string(entry.value, 500);
      if (key != null && value != null) {
        tags[key] = value;
      }
      if (tags.length >= 100) {
        break;
      }
    }
    return tags;
  }

  /// The first present, non-empty value among [keys] in the `extratags` map,
  /// bounded to [maxLength]. Extra tags are attacker-controlled OSM data.
  static String? _contact(
    Map<Object?, Object?>? extra,
    List<String> keys,
    int maxLength,
  ) {
    if (extra == null) {
      return null;
    }
    for (final String key in keys) {
      final String? value = _string(extra[key], maxLength);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  /// OSM's three-valued `wheelchair` tag: `yes`/`designated` → true, `no` →
  /// false, anything else (including `limited`) → unknown.
  static bool? _wheelchair(Map<Object?, Object?>? extra) {
    final String? value = _contact(extra, const <String>['wheelchair'], 20);
    return switch (value?.toLowerCase()) {
      'yes' || 'designated' || 'true' || '1' => true,
      'no' || 'false' || '0' => false,
      _ => null,
    };
  }

  static String? _addressFallback(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final String? street = _string(raw['road'], 120);
    final String? number = _string(raw['house_number'], 20);
    if (street == null) {
      return null;
    }
    return number == null ? street : '$number $street';
  }

  static String? _firstSegment(String? displayName) {
    if (displayName == null) {
      return null;
    }
    final String first = displayName.split(',').first.trim();
    return first.isEmpty ? null : first;
  }

  static String? _string(Object? raw, int maxLength) {
    if (raw is! String) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }
}

/// A parsed OSM reference, in both our own form (`way/123`) and Nominatim's
/// (`W123`).
class _Ref {
  const _Ref({required this.ref, required this.nominatimId});

  final String ref;
  final String nominatimId;

  static _Ref? parse(String raw) {
    final String value = raw.trim();
    if (!OsmRef.isRef(value)) {
      return null;
    }
    final int slash = value.indexOf('/');
    final String type = value.substring(0, slash).toLowerCase();
    final String id = value.substring(slash + 1);
    final String prefix = switch (type) {
      OsmRef.node => 'N',
      OsmRef.way => 'W',
      OsmRef.relation => 'R',
      _ => '',
    };
    if (prefix.isEmpty) {
      return null;
    }
    return _Ref(ref: '$type/$id', nominatimId: '$prefix$id');
  }
}
