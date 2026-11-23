import '../../core/utils/currency.dart';
import 'lat_lon.dart';
import 'price_range.dart';

/// Who a review is published for.
///
/// `public` is a plain Nostr event anyone can read. `friends` is the viewer's
/// private channel — **not implemented yet** (see `plan/architecture.md` §11);
/// the UI offers the choice, but a friends-only review cannot be published
/// until the encrypted path lands.
enum ReviewVisibility { public, friends }

/// A place review published as a Nostr event (kind 31987).
///
/// One review per author **per place**: the event's `d` tag is the place key, so
/// re-publishing replaces the author's previous review (edit) rather than adding
/// another.
class Review {
  const Review({
    required this.id,
    required this.authorPubkey,
    required this.placeKey,
    required this.rating,
    required this.content,
    required this.position,
    required this.createdAt,
    this.photos = const <String>[],
    this.authorName,
    this.authorPicture,
    this.isFriend = false,
    this.priceAmount,
    this.priceCurrency,
  });

  /// The Nostr event id (stable identity of the review).
  final String id;

  /// The author's public key (lowercase hex).
  final String authorPubkey;

  /// The place this review is about — the `d` tag value, e.g.
  /// `openstreetmap:way/123456`.
  final String placeKey;

  /// The normalised rating in `0..1` (`0.8` → 4 of 5 stars). This is exactly
  /// what the event's `rating` tag stores.
  final double rating;

  /// The review text. Photo links are part of it, as is usual on Nostr.
  final String content;

  /// Where the review was left, decoded from the event's full-precision
  /// geohash (`g`) tag.
  final LatLon position;

  final DateTime createdAt;

  /// Image URLs extracted from [content] (Blossom links).
  final List<String> photos;

  /// The author's display name, resolved by the viewer's social layer when
  /// known. Viewer-relative, like a friend marker's label.
  final String? authorName;

  /// The author's profile picture URL when known.
  final String? authorPicture;

  /// Whether the author is one of the signed-in viewer's friends. Set by the
  /// state layer; a review event itself carries no such flag.
  final bool isFriend;

  /// The per-person price amount the reviewer reported, from the event's
  /// `price` tag (in [priceCurrency]). `null` means the review said nothing
  /// about price. `0` means free.
  final double? priceAmount;

  /// The ISO-4217 currency of [priceAmount] (e.g. `EUR`). `null` for a free
  /// price, which is currency-agnostic.
  final String? priceCurrency;

  /// The price band this review's amount falls in, using its own currency when
  /// known and [fallback] otherwise, or `null` when it reported no usable price.
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

  /// The rating on the familiar 0–5 star scale (may be fractional, e.g. 4.8).
  double get stars => rating * 5;

  /// The rating rounded to the nearest whole star, `0` when unrated.
  int get roundedStars => rating <= 0 ? 0 : stars.round().clamp(1, 5);

  /// [content] with the photo links removed — what the reviewer actually typed.
  String get bodyText {
    if (photos.isEmpty) {
      return content.trim();
    }
    String text = content;
    for (final String url in photos) {
      text = text.replaceAll(url, '');
    }
    return text.trim();
  }

  Review copyWith({
    List<String>? photos,
    String? authorName,
    String? authorPicture,
    bool? isFriend,
    double? priceAmount,
    String? priceCurrency,
  }) => Review(
    id: id,
    authorPubkey: authorPubkey,
    placeKey: placeKey,
    rating: rating,
    content: content,
    position: position,
    createdAt: createdAt,
    photos: photos ?? this.photos,
    authorName: authorName ?? this.authorName,
    authorPicture: authorPicture ?? this.authorPicture,
    isFriend: isFriend ?? this.isFriend,
    priceAmount: priceAmount ?? this.priceAmount,
    priceCurrency: priceCurrency ?? this.priceCurrency,
  );

  @override
  bool operator ==(Object other) =>
      other is Review &&
      other.id == id &&
      other.isFriend == isFriend &&
      other.rating == rating &&
      other.content == content &&
      other.authorName == authorName &&
      other.authorPicture == authorPicture &&
      other.priceAmount == priceAmount &&
      other.priceCurrency == priceCurrency &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    isFriend,
    rating,
    content,
    authorName,
    authorPicture,
    priceAmount,
    priceCurrency,
    createdAt,
  );

  @override
  String toString() => 'Review($id, $placeKey, $rating)';
}
