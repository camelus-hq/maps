import '../entities/lat_lon.dart';
import '../entities/lat_lon_bounds.dart';
import '../entities/place.dart';

/// Forward geocoding and autocomplete.
///
/// Implemented by Mapbox Geocoding or Photon in `data/`.
abstract interface class SearchService {
  /// Searches for [query]. When [proximity] is given the results are biased
  /// toward that point (the user's location), for "near me" behaviour; when
  /// [bounds] is given the results are limited to that rectangle.
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  });

  /// Points of interest of the given canonical [categoryId] near [proximity]
  /// ("Restaurants around me").
  ///
  /// When [bounds] is given the results are limited to that rectangle (the map
  /// viewport) — implementations that support a bounding-box query should use
  /// it, others may filter or ignore it. Implementations that lack a category
  /// index may throw an [AppException]; callers fall back to [search].
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  });
}
