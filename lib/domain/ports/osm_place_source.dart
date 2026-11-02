import '../entities/place.dart';

/// Resolves an OpenStreetMap element reference into a displayable [Place].
///
/// Reviews are keyed by the OSM element (`node/2764050762`, `way/123`), which
/// is what makes a review findable again — but it is not something to show the
/// user. When a review badge is tapped and the place is not already in our data,
/// this looks the element up in OpenStreetMap so the sheet shows the real name
/// and address instead of `node/2764050762`.
///
/// Implemented in `data/osm/` (the public Nominatim lookup endpoint, OSM data)
/// and by an in-memory fake for tests and keyless runs.
abstract interface class OsmPlaceSource {
  /// The element named by [osmRef] (e.g. `way/123456`), or `null` when it does
  /// not exist.
  ///
  /// Throws an [AppException] when the lookup could not be made (network,
  /// timeout, hostile response) — the caller decides whether to fall back to
  /// the raw reference.
  Future<Place?> lookup(String osmRef);
}
