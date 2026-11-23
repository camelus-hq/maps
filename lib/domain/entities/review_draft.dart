import 'dart:typed_data';

import '../../core/utils/currency.dart';
import 'lat_lon.dart';
import 'price_range.dart';
import 'review.dart';

/// A photo attached to a review, held in memory until publish.
///
/// On publish it is uploaded to a Blossom server (see `ReviewService`) and the
/// resulting URL is appended to the review's content, the usual place for image
/// links on Nostr.
class ReviewPhoto {
  const ReviewPhoto({required this.data, this.mimeType, this.filename});

  final Uint8List data;

  /// Optional content type (e.g. `image/jpeg`).
  final String? mimeType;

  /// Optional original file name (for diagnostics only).
  final String? filename;

  int get sizeBytes => data.length;

  bool get isEmpty => data.isEmpty;
}

/// Everything needed to publish (or republish/edit) a review.
///
/// Validated by the publish use case before it reaches the port: a rating above
/// zero, bounded text, at most [maxPhotos] photos, and — for a place whose
/// category charges one ([priceApplies]) — a per-person price.
class ReviewDraft {
  const ReviewDraft({
    required this.placeKey,
    required this.position,
    this.rating = 0,
    this.text = '',
    this.visibility = ReviewVisibility.public,
    this.photos = const <ReviewPhoto>[],
    this.photoUrls = const <String>[],
    this.priceAmount,
    this.priceCurrency,
    this.priceApplies = false,
  });

  /// The `d` tag value of the target place, e.g. `openstreetmap:way/123456`.
  final String placeKey;

  /// The place coordinate, used to write the `g` geohash tags.
  final LatLon position;

  /// Normalised rating in `0..1` (`0` = not rated yet).
  final double rating;

  /// The review text (without photo links; those are appended on publish).
  final String text;

  final ReviewVisibility visibility;

  /// Local photos to upload to Blossom on publish.
  final List<ReviewPhoto> photos;

  /// Photo links already published with an earlier version of this review
  /// (kept so editing does not drop them).
  final List<String> photoUrls;

  /// The per-person price **amount** the reviewer picked, in [priceCurrency]
  /// (`0` for free). `null` while unset.
  final double? priceAmount;

  /// The ISO-4217 currency of [priceAmount] (e.g. `EUR`); `null` for a free
  /// price, which is currency-agnostic.
  final String? priceCurrency;

  /// Whether the place charges a per-person price, so the composer asks and
  /// [canPublish] requires an answer. Set by the composer from the place's
  /// category (via `priceRangeAppliesToCategory`).
  final bool priceApplies;

  /// The band [priceAmount] falls in, using its own currency when known and
  /// [fallback] otherwise (the place's currency). `null` while unset.
  PriceRange? priceBand(CurrencyInfo? fallback) {
    final double? amount = priceAmount;
    if (amount == null) {
      return null;
    }
    if (amount <= 0) {
      return PriceRange.free;
    }
    return PriceRange.fromValue(
      amount,
      currencyInfoForCode(priceCurrency) ?? fallback,
    );
  }

  /// At most five photos per review.
  static const int maxPhotos = 5;

  /// Longest allowed review text (matches the composer's character counter).
  static const int maxTextLength = 1000;

  double get stars => rating * 5;

  /// Total number of photos (kept links + new local ones).
  int get photoCount => photos.length + photoUrls.length;

  bool get canPublish =>
      rating > 0 &&
      visibility == ReviewVisibility.public &&
      (!priceApplies || priceAmount != null) &&
      !(text.trim().isEmpty && photoCount == 0);

  ReviewDraft copyWith({
    String? placeKey,
    LatLon? position,
    double? rating,
    String? text,
    ReviewVisibility? visibility,
    List<ReviewPhoto>? photos,
    List<String>? photoUrls,
    double? priceAmount,
    String? priceCurrency,
    bool clearPrice = false,
    bool? priceApplies,
  }) => ReviewDraft(
    placeKey: placeKey ?? this.placeKey,
    position: position ?? this.position,
    rating: rating ?? this.rating,
    text: text ?? this.text,
    visibility: visibility ?? this.visibility,
    photos: photos ?? this.photos,
    photoUrls: photoUrls ?? this.photoUrls,
    priceAmount: clearPrice ? null : (priceAmount ?? this.priceAmount),
    priceCurrency: clearPrice ? null : (priceCurrency ?? this.priceCurrency),
    priceApplies: priceApplies ?? this.priceApplies,
  );

  @override
  String toString() =>
      'ReviewDraft($placeKey, rating: $rating, '
      'price: $priceAmount $priceCurrency, photos: $photoCount)';
}
