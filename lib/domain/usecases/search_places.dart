import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/lat_lon.dart';
import '../entities/lat_lon_bounds.dart';
import '../entities/place.dart';
import '../ports/search_service.dart';

/// Validates and runs a forward-geocoding query through [SearchService].
class SearchPlaces {
  const SearchPlaces(this._searchService);

  final SearchService _searchService;

  static const int _minQueryLength = 2;
  static const int _maxQueryLength = 200;

  Future<Result<List<Place>>> call(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.length < _minQueryLength) {
      return const Err(ValidationException('Search query is too short'));
    }
    if (trimmed.length > _maxQueryLength) {
      return const Err(ValidationException('Search query is too long'));
    }
    try {
      final List<Place> places = await _searchService.search(
        trimmed,
        proximity: proximity,
        // An area search (a category fallback) is capped to a local box.
        bounds: bounds?.cappedToMaxSpanMeters(
          LatLonBounds.maxAreaSearchSpanMeters,
        ),
      );
      return Ok(places);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Search failed', cause: error));
    }
  }
}
