import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/place.dart';
import '../ports/places_repository.dart';

/// Adds or removes a bookmark through [PlacesRepository].
class ToggleBookmark {
  const ToggleBookmark(this._placesRepository);

  final PlacesRepository _placesRepository;

  /// Returns the resulting bookmark state.
  Future<Result<bool>> call(Place place, {required bool bookmarked}) async {
    try {
      await _placesRepository.setBookmark(place, bookmarked: bookmarked);
      return Ok(bookmarked);
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Could not update bookmark', cause: error));
    }
  }
}
