import '../../core/errors/app_exception.dart';
import '../entities/review.dart';
import '../entities/review_draft.dart';
import '../entities/review_place.dart';
import '../ports/review_service.dart';

/// Validates a review draft and publishes it.
///
/// All the rules live here rather than in the widget so the UI, the control
/// channel and tests share one behaviour: a place key in our namespace, a
/// rating in `0..1`, bounded text and at most five photos.
class PublishReview {
  const PublishReview(this._service);

  final ReviewService _service;

  Future<void> call(ReviewDraft draft) async {
    if (!ReviewPlace.isValidKey(draft.placeKey)) {
      throw const ValidationException('This place cannot be reviewed');
    }
    if (!draft.rating.isFinite || draft.rating <= 0 || draft.rating > 1) {
      throw const ValidationException('Add a star rating before publishing');
    }
    if (draft.visibility == ReviewVisibility.friends) {
      throw const UnsupportedException(
        'Friends-only reviews are not available yet',
      );
    }
    if (draft.text.trim().length > ReviewDraft.maxTextLength) {
      throw const ValidationException('Your review is too long');
    }
    if (draft.photos.length > ReviewDraft.maxPhotos) {
      throw const ValidationException('You can add at most five photos');
    }
    if (!_service.isLoggedIn) {
      throw const ValidationException('Sign in to publish a review');
    }
    await _service.publishReview(draft);
  }
}
