import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/lat_lon_bounds.dart';
import '../../domain/entities/place.dart';
import '../../domain/ports/search_service.dart';
import 'sample_data.dart';

/// Keyless, in-memory [SearchService] used until Mapbox geocoding lands (M3).
class FakeSearchService implements SearchService {
  const FakeSearchService();

  static const int _maxResults = 10;

  @override
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return const <Place>[];
    }
    return SampleData.places
        .where(
          (Place place) =>
              (place.name.toLowerCase().contains(needle) ||
                  (place.category?.toLowerCase().contains(needle) ?? false)) &&
              (bounds == null || bounds.contains(place.position)),
        )
        .take(_maxResults)
        .toList(growable: false);
  }

  @override
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  }) async {
    final Iterable<Place> nearby = bounds == null
        ? SampleData.places
        : SampleData.places.where(
            (Place place) => bounds.contains(place.position),
          );
    return nearby.take(limit).toList(growable: false);
  }
}
