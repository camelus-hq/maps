import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../data/fakes/fake_review_service.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/friend.dart';
import '../domain/entities/place.dart';
import '../domain/entities/review.dart';
import '../domain/entities/review_bounds.dart';
import '../domain/entities/review_draft.dart';
import '../domain/entities/review_marker.dart';
import '../domain/entities/review_place.dart';
import '../domain/entities/review_summary.dart';
import '../domain/ports/review_service.dart';
import '../domain/usecases/load_reviews.dart';
import '../domain/usecases/publish_review.dart';
import 'ports.dart';
import 'social.dart';
import 'usecases.dart';

/// The keyless demo review service when the app runs on fakes, else `null`.
///
/// Lets the control channel inject a synthetic review
/// (`review.simulate.add`) so the map badges and the place sheet can be driven
/// and screenshotted without relays.
final Provider<FakeReviewService?> demoReviewServiceProvider =
    Provider<FakeReviewService?>((Ref ref) {
      final ReviewService service = ref.watch(reviewServiceProvider);
      return service is FakeReviewService ? service : null;
    });

/// Resolves and caches the display name/picture of a review's author.
///
/// A place's reviews all come from different authors; without a cache the same
/// profile would be fetched once per rebuild. The social service is the only
/// thing that talks to relays here.
class ReviewAuthorResolver {
  ReviewAuthorResolver(this._resolveProfile);

  final Future<Friend> Function(String pubkey) _resolveProfile;

  final Map<String, Friend> _cache = <String, Friend>{};

  /// How many authors we resolve in one enrichment pass (hostile-input bound).
  static const int maxAuthors = 24;

  Future<Friend> resolve(String pubkey) async {
    final Friend? cached = _cache[pubkey];
    if (cached != null) {
      return cached;
    }
    Friend friend;
    try {
      friend = await _resolveProfile(pubkey);
    } catch (_) {
      friend = Friend(pubkey: pubkey);
    }
    _cache[pubkey] = friend;
    return friend;
  }
}

final Provider<ReviewAuthorResolver> reviewAuthorResolverProvider =
    Provider<ReviewAuthorResolver>(
      (Ref ref) => ReviewAuthorResolver(
        (String pubkey) =>
            ref.read(socialServiceProvider).resolveProfile(pubkey),
      ),
    );

/// Marks which reviews came from the viewer's friends and fills in author
/// names/pictures (from the friends list, else the network).
Future<List<Review>> enrichReviews(Ref ref, List<Review> reviews) async {
  if (reviews.isEmpty) {
    return const <Review>[];
  }
  final Map<String, Friend> friends = ref.read(friendsByPubkeyProvider);
  final ReviewAuthorResolver resolver = ref.read(reviewAuthorResolverProvider);
  final Map<String, Friend> resolved = <String, Friend>{};
  final List<String> unknown = <String>[];
  for (final Review review in reviews) {
    if (friends.containsKey(review.authorPubkey) ||
        review.authorName != null ||
        resolved.containsKey(review.authorPubkey) ||
        unknown.contains(review.authorPubkey)) {
      continue;
    }
    unknown.add(review.authorPubkey);
    if (unknown.length >= ReviewAuthorResolver.maxAuthors) {
      break;
    }
  }
  if (unknown.isNotEmpty) {
    final List<Friend> profiles = await Future.wait(
      unknown.map(resolver.resolve),
    );
    for (final Friend profile in profiles) {
      resolved[profile.pubkey] = profile;
    }
  }
  return <Review>[
    for (final Review review in reviews) _decorate(review, friends, resolved),
  ];
}

Review _decorate(
  Review review,
  Map<String, Friend> friends,
  Map<String, Friend> resolved,
) {
  final Friend? friend = friends[review.authorPubkey];
  if (friend != null) {
    return review.copyWith(
      isFriend: true,
      authorName: friend.label,
      authorPicture: friend.pictureUrl,
    );
  }
  if (review.authorName != null) {
    return review;
  }
  final Friend? profile = resolved[review.authorPubkey];
  if (profile == null) {
    return review;
  }
  return review.copyWith(
    authorName: profile.label,
    authorPicture: profile.pictureUrl,
  );
}

/// The reviews for one place, with author **names** resolved (friend flags are
/// applied by [placeReviewSummaryProvider], so this provider never has to wait
/// on the friend graph).
final placeReviewsProvider = FutureProvider.family<List<Review>, String>((
  Ref ref,
  String placeKey,
) async {
  if (!ReviewPlace.isValidKey(placeKey)) {
    return const <Review>[];
  }
  final LoadPlaceReviews load = ref.read(loadPlaceReviewsProvider);
  final List<Review> reviews = await load(placeKey);
  return enrichReviews(ref, reviews);
});

/// The per-place summary the place sheet renders: the reviews, the friend flags
/// and the average.
///
/// It is a **sync** provider that watches the friend graph, so a place opened
/// before the friends list finished loading still lights up its friend reviews
/// the moment they arrive — without ever making the review fetch wait for it.
final placeReviewSummaryProvider = Provider.family<ReviewSummary, String>((
  Ref ref,
  String placeKey,
) {
  final List<Review> reviews =
      ref.watch(placeReviewsProvider(placeKey)).value ?? const <Review>[];
  if (reviews.isEmpty) {
    return ReviewSummary.empty(placeKey);
  }
  final Map<String, Friend> friends = ref.watch(friendsByPubkeyProvider);
  return ReviewSummary(
    placeKey: placeKey,
    reviews: <Review>[
      for (final Review review in reviews) decorateWithFriend(review, friends),
    ],
  );
});

/// Applies the viewer's friend graph to [review]: marks it as a friend's and
/// prefers the friend's profile name/picture.
Review decorateWithFriend(Review review, Map<String, Friend> friends) {
  final Friend? friend = friends[review.authorPubkey];
  if (friend == null) {
    return review;
  }
  return review.copyWith(
    isFriend: true,
    authorName: friend.label,
    authorPicture: friend.pictureUrl,
  );
}

/// The reviews on screen, as one badge per reviewed place.
///
/// The map home drives this through [ReviewMapLayer]: whenever the camera
/// settles it asks for the reviews inside the visible rectangle (geohash query
/// behind [reviewServiceProvider]) and paints one badge per place. A badge for a
/// place a friend has reviewed is highlighted.
///
/// Two map problems are handled here, in one place, because both need the
/// camera and the viewport:
/// - **Zoomed out**, badges would blanket the map and never be readable, so
///   nothing is drawn ([minZoom]) and no query is made.
/// - **Overlapping** badges (places close together) are collapsed to the most
///   relevant one — **a friend's review always wins** ([_dropOverlaps]).
class ReviewMarkersController extends Notifier<List<ReviewMarker>> {
  /// Badges are hidden below this zoom. At city scale they would cover the map
  /// (and each other) and none would be readable.
  static const double minZoom = 14;

  /// Estimated size of a composed badge **as drawn on the map**, used for the
  /// overlap test: the composer's own geometry scaled by
  /// [ReviewMarker.onMapScale], so it tracks the map layer automatically.
  static double _badgeWidth(ReviewMarker marker) =>
      (ReviewMarker.basePadX * 2 +
          ReviewMarker.baseStarAndGap +
          marker.badgeLabel.length * ReviewMarker.baseCharWidth) *
      ReviewMarker.onMapScale;

  static double get _badgeHeight =>
      ReviewMarker.baseHeight * ReviewMarker.onMapScale;

  int _requestSeq = 0;
  bool _loading = false;
  bool _pending = false;
  ReviewBounds? _lastBounds;
  ReviewBounds? _lastLoadedBounds;
  Camera? _camera;
  Size? _viewport;
  List<Review> _raw = const <Review>[];
  List<ReviewMarker> _all = const <ReviewMarker>[];
  bool _friendOnly = false;

  /// Whether only friend-reviewed places are currently drawn.
  bool get friendOnly => _friendOnly;

  @override
  List<ReviewMarker> build() {
    // The friend graph often arrives after the first query; recompose the
    // badges (highlighting friends) as soon as it does.
    ref.listen<Map<String, Friend>>(friendsByPubkeyProvider, (
      Map<String, Friend>? _,
      Map<String, Friend> _,
    ) {
      if (_raw.isEmpty) {
        return;
      }
      _all = _compose(_raw);
      _emit();
    });
    return const <ReviewMarker>[];
  }

  /// Records the camera + viewport and (re)queries the visible rectangle.
  ///
  /// Queries coalesce: while one is in flight the newest bounds are remembered
  /// and run once it finishes, so a pan cannot queue up a storm of queries (and
  /// no timer is ever left behind).
  void update(Camera camera, Size viewport) {
    if (!viewport.width.isFinite || !viewport.height.isFinite) {
      return;
    }
    _camera = camera;
    _viewport = viewport;
    if (camera.zoom < minZoom) {
      // Too far out to show anything (and not worth a query).
      _lastBounds = null;
      _lastLoadedBounds = null;
      _raw = const <Review>[];
      _all = const <ReviewMarker>[];
      if (state.isNotEmpty) {
        _emit();
      }
      return;
    }
    final ReviewBounds bounds = ReviewBounds.fromCamera(
      camera,
      widthPx: viewport.width,
      heightPx: viewport.height,
    );
    _lastBounds = bounds;
    final ReviewBounds? lastLoaded = _lastLoadedBounds;
    if (lastLoaded != null && _sameBounds(lastLoaded, bounds)) {
      return;
    }
    if (_loading) {
      _pending = true;
      return;
    }
    unawaited(_drain());
  }

  /// Re-queries the last known viewport (after publishing, say).
  Future<void> refresh() async {
    final ReviewBounds? bounds = _lastBounds;
    if (bounds == null) {
      return;
    }
    _lastLoadedBounds = null;
    await _drain();
  }

  /// Draws only places a friend has reviewed (the "Friend's review" mode).
  void setFriendOnly(bool value) {
    if (_friendOnly == value) {
      return;
    }
    _friendOnly = value;
    _emit();
  }

  Future<void> _drain() async {
    if (_loading) {
      _pending = true;
      return;
    }
    _loading = true;
    try {
      do {
        _pending = false;
        final ReviewBounds? bounds = _lastBounds;
        if (bounds == null) {
          break;
        }
        await _load(bounds);
      } while (_pending && ref.mounted);
    } finally {
      _loading = false;
    }
  }

  Future<void> _load(ReviewBounds bounds) async {
    final int seq = ++_requestSeq;
    final List<Review> reviews;
    try {
      final LoadVisibleReviews load = ref.read(loadVisibleReviewsProvider);
      reviews = await load(bounds);
    } on AppException {
      // Keep the badges we already have; the next camera move retries.
      return;
    }
    if (!ref.mounted || seq != _requestSeq) {
      return;
    }
    final List<Review> enriched = await enrichReviews(ref, reviews);
    if (!ref.mounted || seq != _requestSeq) {
      return;
    }
    _lastLoadedBounds = bounds;
    _raw = enriched;
    _all = _compose(enriched);
    _emit();
  }

  /// Whether two viewports are close enough that a re-query is pointless.
  bool _sameBounds(ReviewBounds a, ReviewBounds b) {
    return (a.latSpan - b.latSpan).abs() < 1e-6 &&
        (a.lonSpan - b.lonSpan).abs() < 1e-6 &&
        a.center.distanceTo(b.center) < 25;
  }

  /// Groups reviews by place, produces one badge each, then drops the badges
  /// that would overlap — keeping the most relevant (friends first).
  List<ReviewMarker> _compose(List<Review> reviews) {
    final Map<String, Friend> friends = ref.read(friendsByPubkeyProvider);
    final Map<String, List<Review>> byPlace = <String, List<Review>>{};
    for (final Review review in reviews) {
      final Review decorated = decorateWithFriend(review, friends);
      (byPlace[decorated.placeKey] ??= <Review>[]).add(decorated);
    }
    final List<ReviewMarker> markers = <ReviewMarker>[];
    for (final MapEntry<String, List<Review>> entry in byPlace.entries) {
      final List<Review> list = entry.value;
      double sum = 0;
      int friends = 0;
      String? topFriend;
      for (final Review review in list) {
        sum += review.rating;
        if (review.isFriend) {
          friends++;
          topFriend ??= review.authorName;
        }
      }
      markers.add(
        ReviewMarker(
          placeKey: entry.key,
          position: list.first.position,
          averageRating: list.isEmpty ? 0 : sum / list.length,
          reviewCount: list.length,
          friendCount: friends,
          topFriendName: topFriend,
        ),
      );
    }
    // Rank before the overlap test: a friend's review is the one worth keeping.
    markers.sort(_byPriority);
    return List<ReviewMarker>.unmodifiable(_dropOverlaps(markers));
  }

  /// Most relevant first: friend reviews, then more reviews, then a higher
  /// average; the place key breaks ties so the result is stable.
  int _byPriority(ReviewMarker a, ReviewMarker b) {
    final int friends = b.friendCount.compareTo(a.friendCount);
    if (friends != 0) {
      return friends;
    }
    final int count = b.reviewCount.compareTo(a.reviewCount);
    if (count != 0) {
      return count;
    }
    final int rating = b.averageRating.compareTo(a.averageRating);
    if (rating != 0) {
      return rating;
    }
    return a.placeKey.compareTo(b.placeKey);
  }

  /// Greedily keeps the highest-priority badge from each cluster of overlapping
  /// badges. [markers] must already be in priority order.
  List<ReviewMarker> _dropOverlaps(List<ReviewMarker> markers) {
    final Camera? camera = _camera;
    final Size? viewport = _viewport;
    if (markers.length < 2 || camera == null || viewport == null) {
      return markers;
    }
    final List<Rect> kept = <Rect>[];
    final List<ReviewMarker> result = <ReviewMarker>[];
    for (final ReviewMarker marker in markers) {
      final Rect rect = _screenRect(marker, camera, viewport);
      if (kept.any((Rect keptRect) => keptRect.overlaps(rect))) {
        continue;
      }
      kept.add(rect);
      result.add(marker);
    }
    return result;
  }

  /// The badge's rectangle in viewport pixels (a mercator approximation is
  /// plenty at city scale).
  Rect _screenRect(ReviewMarker marker, Camera camera, Size viewport) {
    final double latRadians = camera.target.latitude * math.pi / 180;
    final double cosLat = math.cos(latRadians).abs();
    final double metersPerPixel =
        156543.03392 *
        cosLat /
        math.pow(2, camera.zoom.clamp(0.0, 22.0)).toDouble();
    final double dxMeters =
        (marker.position.longitude - camera.target.longitude) *
        111320 *
        (cosLat < 0.01 ? 0.01 : cosLat);
    final double dyMeters =
        (marker.position.latitude - camera.target.latitude) * 111320;
    final double cx = viewport.width / 2 + dxMeters / metersPerPixel;
    final double cy = viewport.height / 2 - dyMeters / metersPerPixel;
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: _badgeWidth(marker),
      height: _badgeHeight,
    );
  }

  void _emit() {
    final List<ReviewMarker> next = _friendOnly
        ? <ReviewMarker>[
            for (final ReviewMarker marker in _all)
              if (marker.hasFriendReview) marker,
          ]
        : _all;
    final List<ReviewMarker> value = List<ReviewMarker>.unmodifiable(next);
    state = value;
    unawaited(ref.read(mapServiceProvider).setReviewMarkers(value));
  }
}

final NotifierProvider<ReviewMarkersController, List<ReviewMarker>>
reviewMarkersProvider =
    NotifierProvider<ReviewMarkersController, List<ReviewMarker>>(
      ReviewMarkersController.new,
    );

/// The places on screen that at least one friend has reviewed.
final Provider<List<ReviewMarker>> friendReviewMarkersProvider =
    Provider<List<ReviewMarker>>((Ref ref) {
      return <ReviewMarker>[
        for (final ReviewMarker marker in ref.watch(reviewMarkersProvider))
          if (marker.hasFriendReview) marker,
      ];
    });

/// The state of the "Write a review" sheet.
enum ReviewComposerStatus { idle, publishing, published, error }

class ReviewComposerState {
  const ReviewComposerState({
    this.place,
    this.draft,
    this.status = ReviewComposerStatus.idle,
    this.error,
  });

  /// The place being reviewed, or `null` when the composer is closed.
  final Place? place;

  final ReviewDraft? draft;

  final ReviewComposerStatus status;

  /// A user-readable failure from the last publish attempt.
  final String? error;

  bool get isOpen => place != null;

  bool get isPublishing => status == ReviewComposerStatus.publishing;

  bool get isPublished => status == ReviewComposerStatus.published;

  /// The draft's rating on the whole-star scale, `0` when unrated.
  int get stars {
    final double rating = draft?.rating ?? 0;
    return rating <= 0 ? 0 : (rating * 5).round().clamp(1, 5);
  }

  ReviewComposerState copyWith({
    Place? place,
    ReviewDraft? draft,
    ReviewComposerStatus? status,
    String? error,
    bool clearError = false,
  }) => ReviewComposerState(
    place: place ?? this.place,
    draft: draft ?? this.draft,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives the "Write a review" sheet: the draft, the visibility choice and the
/// publish action. All side effects (the Nostr publish, the Blossom upload) run
/// here, never in the widget.
class ReviewComposerController extends Notifier<ReviewComposerState> {
  @override
  ReviewComposerState build() => const ReviewComposerState();

  /// Opens the composer for [place], optionally prefilled with [initial].
  void open(Place place, {ReviewDraft? initial}) {
    state = ReviewComposerState(
      place: place,
      draft:
          initial ??
          ReviewDraft(
            placeKey: ReviewPlace.keyFor(place.id),
            position: place.position,
          ),
    );
  }

  void close() {
    state = const ReviewComposerState();
  }

  /// Sets the rating from a whole-star tap (`1..5`).
  void setStars(int stars) {
    final int clamped = stars.clamp(1, 5);
    _updateDraft((ReviewDraft draft) => draft.copyWith(rating: clamped / 5));
  }

  void setRating(double rating) {
    if (!rating.isFinite) {
      return;
    }
    _updateDraft(
      (ReviewDraft draft) => draft.copyWith(rating: rating.clamp(0.0, 1.0)),
    );
  }

  void setText(String text) {
    final String bounded = text.length > ReviewDraft.maxTextLength
        ? text.substring(0, ReviewDraft.maxTextLength)
        : text;
    _updateDraft((ReviewDraft draft) => draft.copyWith(text: bounded));
  }

  void setVisibility(ReviewVisibility visibility) {
    _updateDraft((ReviewDraft draft) => draft.copyWith(visibility: visibility));
  }

  void addPhotos(List<ReviewPhoto> photos) {
    if (photos.isEmpty) {
      return;
    }
    final ReviewDraft? draft = state.draft;
    if (draft == null) {
      return;
    }
    final List<ReviewPhoto> next = <ReviewPhoto>[...draft.photos];
    for (final ReviewPhoto photo in photos) {
      if (photo.isEmpty ||
          next.length + draft.photoUrls.length >= ReviewDraft.maxPhotos) {
        continue;
      }
      next.add(photo);
    }
    _updateDraft((ReviewDraft draft) => draft.copyWith(photos: next));
  }

  void removePhotoAt(int index) {
    final ReviewDraft? draft = state.draft;
    if (draft == null || index < 0 || index >= draft.photos.length) {
      return;
    }
    final List<ReviewPhoto> next = <ReviewPhoto>[...draft.photos]
      ..removeAt(index);
    _updateDraft((ReviewDraft draft) => draft.copyWith(photos: next));
  }

  /// Removes a photo link carried over from a previously published review.
  void removePhotoUrlAt(int index) {
    final ReviewDraft? draft = state.draft;
    if (draft == null || index < 0 || index >= draft.photoUrls.length) {
      return;
    }
    final List<String> next = <String>[...draft.photoUrls]..removeAt(index);
    _updateDraft((ReviewDraft draft) => draft.copyWith(photoUrls: next));
  }

  void _updateDraft(ReviewDraft Function(ReviewDraft draft) change) {
    final ReviewDraft? draft = state.draft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(draft: change(draft), clearError: true);
  }

  /// Publishes the current draft. On success the state becomes
  /// [ReviewComposerStatus.published]; the sheet closes itself and the place's
  /// reviews are refreshed.
  Future<void> publish() async {
    final ReviewDraft? draft = state.draft;
    if (draft == null || state.isPublishing) {
      return;
    }
    state = state.copyWith(
      status: ReviewComposerStatus.publishing,
      clearError: true,
    );
    try {
      final PublishReview publish = ref.read(publishReviewProvider);
      await publish(draft);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(status: ReviewComposerStatus.published);
      ref.invalidate(placeReviewsProvider(draft.placeKey));
      unawaited(ref.read(reviewMarkersProvider.notifier).refresh());
    } on AppException catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        status: ReviewComposerStatus.error,
        error: error.message,
      );
    }
  }
}

final NotifierProvider<ReviewComposerController, ReviewComposerState>
reviewComposerProvider =
    NotifierProvider<ReviewComposerController, ReviewComposerState>(
      ReviewComposerController.new,
    );

/// Shows only friend-reviewed places on the map (the "Friend's review" mode).
class FriendReviewsOnlyController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) {
      state = value;
    }
  }

  void toggle() => set(!state);
}

final NotifierProvider<FriendReviewsOnlyController, bool>
friendReviewsOnlyProvider = NotifierProvider<FriendReviewsOnlyController, bool>(
  FriendReviewsOnlyController.new,
);

/// Which reviews the viewer marked "Helpful" this session.
///
/// Local and in-memory (reactions over Nostr are a later task), but routed
/// through a command so the UI and agents share the one path.
class HelpfulReviewsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Toggles [id] and returns whether it is now marked helpful.
  bool toggle(String id) {
    final Set<String> next = <String>{...state};
    final bool helpful = !next.remove(id);
    if (helpful) {
      next.add(id);
    }
    state = Set<String>.unmodifiable(next);
    return helpful;
  }

  /// Sets [id]'s helpful flag explicitly.
  bool set(String id, bool helpful) {
    final Set<String> next = <String>{...state};
    if (helpful) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = Set<String>.unmodifiable(next);
    return helpful;
  }
}

final NotifierProvider<HelpfulReviewsController, Set<String>>
helpfulReviewsProvider =
    NotifierProvider<HelpfulReviewsController, Set<String>>(
      HelpfulReviewsController.new,
    );
