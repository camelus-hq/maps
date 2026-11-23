import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';

/// Lenient mapper from a Mapbox Geocoding v5 feature to a domain [Place].
///
/// External JSON is hostile: every field is type-checked and bad entries are
/// dropped (return `null`) rather than throwing.
abstract final class MapboxGeocodingMapper {
  static Place? fromFeature(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final Object? id = raw['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    final String? name = _name(raw);
    if (name == null) {
      return null;
    }
    final LatLon? position = _center(raw['center']);
    if (position == null) {
      return null;
    }
    final Object? placeName = raw['place_name'];
    return Place(
      id: id,
      name: name,
      position: position,
      category: _category(raw),
      address: placeName is String && placeName.isNotEmpty ? placeName : null,
      countryCode: _countryCode(raw),
    );
  }

  /// The country's ISO alpha-2 code: the feature's own `short_code` when it is
  /// a country, else the `country` entry in `properties.context`.
  static String? _countryCode(Map<String, Object?> feature) {
    final Object? properties = feature['properties'];
    if (properties is Map<String, Object?>) {
      final String? own = _alpha2(properties['short_code']);
      if (own != null) {
        return own;
      }
      final String? fromContext = _countryInContext(properties['context']);
      if (fromContext != null) {
        return fromContext;
      }
    }
    return _alpha2(_idCountry(feature['id']));
  }

  static String? _countryInContext(Object? context) {
    if (context is! List<Object?>) {
      return null;
    }
    for (final Object? entry in context) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final Object? id = entry['id'];
      if (id is String && id.startsWith('country.')) {
        return _alpha2(entry['short_code']);
      }
    }
    return null;
  }

  /// A country result's own id looks like `country.de`.
  static String? _idCountry(Object? id) =>
      id is String && id.startsWith('country.') ? id.substring(8) : null;

  static String? _alpha2(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String value = raw.trim().toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(value) ? value : null;
  }

  static String? _name(Map<String, Object?> feature) {
    final Object? text = feature['text'];
    if (text is String && text.trim().isNotEmpty) {
      return text.trim();
    }
    final Object? placeName = feature['place_name'];
    if (placeName is String && placeName.trim().isNotEmpty) {
      return placeName.trim();
    }
    return null;
  }

  static LatLon? _center(Object? raw) {
    if (raw is! List<Object?> || raw.length < 2) {
      return null;
    }
    // GeoJSON order is [longitude, latitude].
    return LatLon.tryParse(raw[1], raw[0]);
  }

  static String? _category(Map<String, Object?> feature) {
    final Object? properties = feature['properties'];
    if (properties is Map<String, Object?>) {
      final Object? category = properties['category'];
      if (category is String && category.trim().isNotEmpty) {
        return category.trim();
      }
      final Object? categories = properties['categories'];
      if (categories is List<Object?>) {
        for (final Object? entry in categories) {
          if (entry is String && entry.trim().isNotEmpty) {
            return entry.trim();
          }
        }
      }
    }
    final Object? category = feature['category'];
    if (category is String && category.trim().isNotEmpty) {
      return category.trim();
    }
    return null;
  }
}
