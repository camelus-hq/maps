/// OpenStreetMap element references and the decoding of provider-encoded ids.
///
/// Pure Dart (L0): a review's place key must name a real OSM element, so this
/// is the one place that knows how an OSM id is spelled.
///
/// Mapbox's vector tiles do not carry an `osm_id` property; the id of an
/// OSM-derived feature **is** the OSM id, transformed so that node/way/relation
/// (whose id spaces overlap) stay unique:
///
/// | OSM type | stored id |
/// |---|---|
/// | node | `id × 10` |
/// | way | `(id × 10) + 1` |
/// | relation | `(id × 10) + 4` |
///
/// So copying a Mapbox feature id into the review's `d` tag produced
/// `openstreetmap:27640507620` for OSM node `2764050762` — one digit too many.
/// [fromEncodedFeatureId] turns it back into `node/2764050762`.
library;

abstract final class OsmRef {
  /// The OSM element types, as used in OSM's own URLs
  /// (`openstreetmap.org/node/1`).
  static const String node = 'node';
  static const String way = 'way';
  static const String relation = 'relation';

  /// The type digit Mapbox appends, mapped to the element type.
  static const Map<int, String> _typeByDigit = <int, String>{
    0: node,
    1: way,
    4: relation,
  };

  /// Decodes a Mapbox-encoded vector-tile feature id into an OSM reference
  /// (`node/2764050762`), or `null` when it is not a decodable OSM id.
  ///
  /// A value of `0` (Mapbox's marker for a feature whose OSM id was dropped
  /// while merging geometries) or an unknown type digit returns `null`, so the
  /// caller keeps its own id instead of inventing an OSM one.
  static String? fromEncodedFeatureId(Object? raw) {
    final int? value = switch (raw) {
      final int v => v,
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (value == null || value <= 0) {
      return null;
    }
    final int osmId = value ~/ 10;
    if (osmId <= 0) {
      return null;
    }
    final String? type = _typeByDigit[value % 10];
    return type == null ? null : '$type/$osmId';
  }

  /// Builds a reference from a type name and a positive id, or `null` when the
  /// type is unknown.
  static String? fromTypeAndId(String type, int id) {
    final String clean = type.trim().toLowerCase();
    if (id <= 0) {
      return null;
    }
    return switch (clean) {
      node || way || relation => '$clean/$id',
      _ => null,
    };
  }

  /// Whether [value] already looks like an OSM reference (`node/1`, `way/2`,
  /// `relation/3`).
  static bool isRef(String value) {
    final int slash = value.indexOf('/');
    if (slash <= 0 || slash == value.length - 1) {
      return false;
    }
    final String type = value.substring(0, slash).toLowerCase();
    if (type != node && type != way && type != relation) {
      return false;
    }
    return int.tryParse(value.substring(slash + 1)) != null;
  }
}
