import '../../core/utils/osm_ref.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';

/// Lenient mapper for **Overpass API** elements (`out center`), the key-less
/// OpenStreetMap query service that powers OpenStreetMap POI categories.
///
/// Hostile-safe: every field is type-checked and a malformed element is dropped
/// (returns `null`), never thrown (AGENTS.md "Never crash"). The element's
/// `type`/`id` become our canonical `node/…` id, so the place sheet can still
/// enrich it through the Nominatim element lookup.
abstract final class OverpassPlaceMapper {
  /// The category tag keys we read, most descriptive first.
  static const List<String> _categoryKeys = <String>[
    'shop',
    'amenity',
    'tourism',
    'leisure',
    'craft',
    'office',
    'healthcare',
    'historic',
    'natural',
  ];

  static Place? fromElement(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final String? type = switch (_string(raw['type'], 20)?.toLowerCase()) {
      OsmRef.node => OsmRef.node,
      OsmRef.way => OsmRef.way,
      OsmRef.relation => OsmRef.relation,
      _ => null,
    };
    final int? id = switch (raw['id']) {
      final int value => value,
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
    if (type == null || id == null) {
      return null;
    }
    final String? ref = OsmRef.fromTypeAndId(type, id);
    if (ref == null) {
      return null;
    }
    final LatLon? position = _position(raw);
    if (position == null) {
      return null;
    }
    final Map<String, String> tags = _tags(raw['tags']);
    final String? category = _category(tags);
    final String? name =
        _string(tags['name'], 120) ??
        (category == null ? null : _humanise(category));
    if (name == null) {
      return null;
    }
    return Place(
      id: ref,
      name: name,
      position: position,
      category: category,
      address: _address(tags),
    );
  }

  /// `node`s carry `lat`/`lon`; `way`s and `relation`s carry a `center` object
  /// when the query asked for `out center`.
  static LatLon? _position(Map<String, Object?> raw) {
    final LatLon? point = LatLon.tryParse(raw['lat'], raw['lon']);
    if (point != null) {
      return point;
    }
    final Object? center = raw['center'];
    if (center is Map<String, Object?>) {
      return LatLon.tryParse(center['lat'], center['lon']);
    }
    return null;
  }

  /// The first present category tag key's value (e.g. `amenity=cafe` → `cafe`).
  static String? _category(Map<String, String> tags) {
    for (final String key in _categoryKeys) {
      final String? value = _string(tags[key], 60);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  /// A readable address from the `addr:*` tags, bounded to 300 characters,
  /// or `null` when the element has none.
  static String? _address(Map<String, String> tags) {
    final String? street = _string(tags['addr:street'], 120);
    final String? number = _string(tags['addr:housenumber'], 20);
    final String? postcode = _string(tags['addr:postcode'], 20);
    final String? city = _string(tags['addr:city'], 120);
    final String built = <String?>[
      if (street != null) number == null ? street : '$number $street',
      if (postcode != null || city != null)
        <String?>[postcode, city].whereType<String>().join(' '),
    ].whereType<String>().join(', ');
    if (built.isEmpty) {
      return null;
    }
    return built.length > 300 ? built.substring(0, 300) : built;
  }

  /// Turns an OSM tag value into a short human label (`fuel` → `Fuel`,
  /// `guest_house` → `Guest house`).
  static String _humanise(String value) {
    final String spaced = value.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) {
      return value;
    }
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// The element's tags, bounded (≤100 keys, ≤500 chars each) and trimmed.
  /// Every value in an Overpass response is attacker-controlled.
  static Map<String, String> _tags(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final Map<String, String> tags = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
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
