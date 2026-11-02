import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/lat_lon.dart';
import '../entities/lat_lon_bounds.dart';
import '../entities/place.dart';
import '../ports/search_service.dart';

/// Finds points of interest of a canonical [categoryId] near the user.
class BrowseCategory {
  const BrowseCategory(this._searchService);

  final SearchService _searchService;

  Future<Result<List<Place>>> call(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
  }) async {
    if (categoryId.trim().isEmpty) {
      return const Err(ValidationException('Category is required'));
    }
    try {
      final List<Place> places = await _searchService.nearbyCategory(
        categoryId.trim(),
        proximity: proximity,
        bounds: bounds?.cappedToMaxSpanMeters(
          LatLonBounds.maxAreaSearchSpanMeters,
        ),
      );
      return Ok(places);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Category search failed', cause: error));
    }
  }
}
