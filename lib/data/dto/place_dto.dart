import 'dart:convert';

import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';

/// Lenient JSON codec for persisting [Place]s (bookmarks).
abstract final class PlaceDto {
  static Map<String, Object?> toJson(Place place) => <String, Object?>{
    'id': place.id,
    'name': place.name,
    'lat': place.position.latitude,
    'lon': place.position.longitude,
    if (place.category != null) 'category': place.category,
    if (place.address != null) 'address': place.address,
    if (place.email != null) 'email': place.email,
    if (place.phone != null) 'phone': place.phone,
    if (place.website != null) 'website': place.website,
    if (place.wheelchairAccessible != null)
      'wheelchair': place.wheelchairAccessible,
    if (place.openingHours != null) 'openingHours': place.openingHours,
    if (place.osmTags.isNotEmpty) 'osmTags': place.osmTags,
  };

  static Place? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final Object? id = raw['id'];
    final Object? name = raw['name'];
    final LatLon? position = LatLon.tryParse(raw['lat'], raw['lon']);
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        position == null) {
      return null;
    }
    final Object? category = raw['category'];
    final Object? address = raw['address'];
    final Object? wheelchair = raw['wheelchair'];
    return Place(
      id: id,
      name: name,
      position: position,
      category: category is String ? category : null,
      address: address is String ? address : null,
      email: _bounded(raw['email'], 254),
      phone: _bounded(raw['phone'], 40),
      website: _bounded(raw['website'], 300),
      wheelchairAccessible: wheelchair is bool ? wheelchair : null,
      openingHours: _bounded(raw['openingHours'], 200),
      osmTags: _tags(raw['osmTags']),
    );
  }

  /// The persisted OSM tag map, filtered to bounded string entries (prefs are
  /// untrusted input too).
  static Map<String, String> _tags(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final Map<String, String> tags = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final String? key = _bounded(entry.key, 100);
      final String? value = _bounded(entry.value, 500);
      if (key != null && value != null) {
        tags[key] = value;
      }
      if (tags.length >= 100) {
        break;
      }
    }
    return tags;
  }

  /// A persisted string, trimmed and bounded (prefs are untrusted input too).
  static String? _bounded(Object? raw, int maxLength) {
    if (raw is! String) {
      return null;
    }
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return value.length > maxLength ? value.substring(0, maxLength) : value;
  }

  static List<Place> decodeList(String? json) {
    if (json == null || json.isEmpty) {
      return const <Place>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const <Place>[];
    }
    if (decoded is! List<Object?>) {
      return const <Place>[];
    }
    final List<Place> places = <Place>[];
    for (final Object? entry in decoded) {
      final Place? place = fromJson(entry);
      if (place != null) {
        places.add(place);
      }
    }
    return places;
  }

  static String encodeList(List<Place> places) =>
      jsonEncode(places.map(toJson).toList(growable: false));
}
