import '../../core/utils/osm_ref.dart';

/// The place key that ties a review to the place it is about.
///
/// Reviews are stored against a **place key**, the value of the Nostr event's
/// `d` tag: our own namespace `openstreetmap:<id>`. When the id is a real OSM
/// element it is written in OSM's own reference form —
/// `openstreetmap:node/2764050762`, `openstreetmap:way/123`, … — so a
/// node/way/relation can never collide (their OSM id spaces overlap).
///
/// Provider-internal ids that carry no OSM id keep their own spelling after the
/// namespace (e.g. `openstreetmap:poi.1234567890` from Mapbox geocoding), which
/// is stable and unique but not an OSM element.
abstract final class ReviewPlace {
  /// The namespace prefix written to the `d` tag.
  static const String prefix = 'openstreetmap:';

  /// Longest accepted place id (hostile input bound).
  static const int maxIdLength = 256;

  /// The place key for a provider/place id, normalising known prefixes so
  /// callers cannot accidentally double-prefix.
  ///
  /// A bare Mapbox-encoded feature id (an OSM id transformed by the vector tile
  /// — see [OsmRef]) is decoded first, so an OSM node arrives as
  /// `node/<id>` rather than its encoded form.
  static String keyFor(String placeId) {
    final String id = placeId.trim();
    if (id.isEmpty) {
      return prefix;
    }
    final String lower = id.toLowerCase();
    if (lower.startsWith(prefix)) {
      return prefix + _normalise(id.substring(prefix.length));
    }
    if (lower.startsWith('osm:')) {
      return prefix + _normalise(id.substring('osm:'.length));
    }
    return prefix + _normalise(id);
  }

  /// Decodes a provider-encoded id to an OSM reference when possible, else
  /// returns it trimmed.
  static String _normalise(String raw) {
    final String value = raw.trim();
    final String? decoded = OsmRef.fromEncodedFeatureId(value);
    return decoded ?? value;
  }

  /// The bare id inside a place key (`openstreetmap:way/1` → `way/1`).
  static String idFromKey(String placeKey) {
    final String key = placeKey.trim();
    if (key.toLowerCase().startsWith(prefix)) {
      return key.substring(prefix.length);
    }
    return key;
  }

  /// Whether [placeKey] is a usable key (right namespace, bounded id).
  static bool isValidKey(String placeKey) {
    final String key = placeKey.trim();
    if (!key.toLowerCase().startsWith(prefix)) {
      return false;
    }
    final String id = key.substring(prefix.length).trim();
    return id.isNotEmpty && key.length <= prefix.length + maxIdLength;
  }
}
