import '../../core/utils/osm_ref.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';

/// Lenient mapper for **Photon** (`photon.komoot.io`) GeoJSON features, the
/// key-less OpenStreetMap geocoder that powers OpenStreetMap search.
///
/// Hostile-safe like the Mapbox mappers: every field is type-checked and a
/// malformed feature is dropped (returns `null`), never thrown (AGENTS.md
/// "Never crash"). The feature's `osm_type`/`osm_id` become our canonical
/// `node/…` / `way/…` / `relation/…` id, so a place's details can still be
/// enriched through the Overpass element lookup and reviews key correctly.
abstract final class PhotonPlaceMapper {
  static Place? fromFeature(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final Object? geometry = raw['geometry'];
    final Object? properties = raw['properties'];
    if (geometry is! Map<String, Object?> ||
        properties is! Map<String, Object?>) {
      return null;
    }
    final LatLon? position = _coordinates(geometry['coordinates']);
    if (position == null) {
      return null;
    }
    final String? id = _id(properties);
    if (id == null) {
      return null;
    }
    final String? name = _name(properties);
    if (name == null) {
      return null;
    }
    return Place(
      id: id,
      name: name,
      position: position,
      category:
          _string(properties['osm_value'], 60) ??
          _string(properties['osm_key'], 60),
      address: _address(properties),
    );
  }

  /// Photon's `osm_type` is `N`/`W`/`R`; combine it with `osm_id` into our
  /// `node/…` form. A feature without a usable OSM id is dropped so we never
  /// invent an id that points at no element.
  static String? _id(Map<String, Object?> properties) {
    final String? type = switch (_string(
      properties['osm_type'],
      4,
    )?.toUpperCase()) {
      'N' => OsmRef.node,
      'W' => OsmRef.way,
      'R' => OsmRef.relation,
      _ => null,
    };
    final int? osmId = switch (properties['osm_id']) {
      final int value => value,
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
    if (type == null || osmId == null) {
      return null;
    }
    return OsmRef.fromTypeAndId(type, osmId);
  }

  /// GeoJSON coordinate order is `[longitude, latitude]`.
  static LatLon? _coordinates(Object? raw) {
    if (raw is! List<Object?> || raw.length < 2) {
      return null;
    }
    return LatLon.tryParse(raw[1], raw[0]);
  }

  /// The place's own name, falling back to a street address when Photon has no
  /// name (house/interpolation results), then to the city. Returns `null` when
  /// nothing readable is present, so the feature is dropped.
  static String? _name(Map<String, Object?> properties) {
    final String? name = _string(properties['name'], 120);
    if (name != null) {
      return name;
    }
    final String? street = _string(properties['street'], 120);
    if (street != null) {
      final String? number = _string(properties['housenumber'], 20);
      return number == null ? street : '$number $street';
    }
    return _string(properties['city'], 120);
  }

  /// A readable address built from Photon's structured fields, bounded to 300
  /// characters. Returns `null` when no part is present.
  static String? _address(Map<String, Object?> properties) {
    final String? street = _string(properties['street'], 120);
    final String? number = _string(properties['housenumber'], 20);
    final String? postcode = _string(properties['postcode'], 20);
    final String? city = _string(properties['city'], 120);
    final String? country = _string(properties['country'], 80);
    final String countryPart = country ?? '';
    final String first = <String>[
      if (street != null) number == null ? street : '$number $street',
      if (postcode != null || city != null)
        <String?>[postcode, city].whereType<String>().join(' '),
      countryPart,
    ].where((String part) => part.isNotEmpty).join(', ');
    if (first.isEmpty) {
      return null;
    }
    return first.length > 300 ? first.substring(0, 300) : first;
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
