import '../entities/review.dart';
import '../entities/review_bounds.dart';
import '../entities/review_draft.dart';

/// Publishes and reads place reviews over Nostr (kind 31987), and uploads the
/// review's photos to Blossom.
///
/// Implemented in `data/nostr/` (NDK) and by an in-memory fake for tests and
/// keyless runs. Nothing outside `data/nostr/` knows the event shape or the
/// Blossom wire format — the geohash indexing, the `rating` normalisation and
/// the photo links in the content all live behind this port.
abstract interface class ReviewService {
  /// Whether a Nostr identity is signed in (reviews are signed events).
  bool get isLoggedIn;

  /// The signed-in user's public key (lowercase hex), or `null`.
  String? get currentUserPubkey;

  /// Publishes [draft] as a parameterised replaceable event whose `d` tag is
  /// the place key, so a second publish by the same author **edits** their
  /// review instead of adding one.
  ///
  /// Any [ReviewDraft.photos] are uploaded to Blossom first and their URLs are
  /// appended to the event content. Throws an [AppException] when signed out,
  /// the draft is invalid, or no relay accepted the event.
  Future<void> publishReview(ReviewDraft draft);

  /// Reviews for a single place (the place sheet), newest first.
  Future<List<Review>> reviewsForPlace(String placeKey);

  /// Reviews whose geohash falls inside [bounds] — the map only ever asks for
  /// what is on screen. Malformed events are dropped, never thrown.
  Future<List<Review>> reviewsInBounds(ReviewBounds bounds);

  /// Uploads [photos] to Blossom and returns their public URLs, in order.
  ///
  /// Throws an [AppException] when no upload server accepted a photo.
  Future<List<String>> uploadPhotos(List<ReviewPhoto> photos);
}
