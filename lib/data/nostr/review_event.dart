import 'package:ndk/entities.dart' show Nip01Event;

import '../../core/utils/geohash.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_place.dart';

/// Encodes/decodes place reviews as Nostr events (kind **31987**).
///
/// The event is a parameterised replaceable event: its `d` tag is the place key
/// (`openstreetmap:<id>`), so one author has at most one review per place and a
/// re-publish edits it.
///
/// ```json
/// {
///   "kind": 31987,
///   "content": "good food",
///   "tags": [
///     ["d", "openstreetmap:way/123456"],
///     ["rating", "0.8"],
///     ["client", "openmaps"],
///     ["g", "u33dbtq4w"],        // full precision
///     ["g", "u33dbtq4"],         // one character less …
///     ["g", "u33dbtq"],
///     ["g", "…"]                 // … down to a single character
///   ]
/// }
/// ```
///
/// The `g` tags carry every enclosing geohash prefix, so a relay can answer a
/// `#g` filter at any zoom level with one round trip.
abstract final class ReviewEvent {
  /// The Nostr kind for a place review (a parameterised replaceable event).
  static const int kind = 31987;

  /// Marks events produced by this app.
  static const String clientName = 'openmaps';

  /// The place-key namespace written to the `d` tag.
  static const String placePrefix = ReviewPlace.prefix;

  /// Characters in the full-precision geohash (~4.8 m), and the shortest prefix
  /// stored. Every length in between is written too.
  static const int fullGeohashPrecision = 9;
  static const int shortestGeohashPrecision = 1;

  /// Bounds applied to all external data (AGENTS.md: treat it as hostile).
  static const int maxContentLength = 8000;
  static const int maxPlaceKeyLength = ReviewPlace.maxIdLength;
  static const int maxPhotoLinks = 10;

  /// The `d` tag value for a place id, normalising any known prefix.
  static String placeKeyFor(String placeId) => ReviewPlace.keyFor(placeId);

  /// The place id inside a `d` tag (`openstreetmap:way/1` → `way/1`), or the
  /// input unchanged when it carries no known prefix.
  static String placeIdFromKey(String placeKey) =>
      ReviewPlace.idFromKey(placeKey);

  /// Whether [placeKey] is a place key this app can write.
  static bool isPlaceKey(String placeKey) => ReviewPlace.isValidKey(placeKey);

  /// The canonical `rating` tag string for a normalised `0..1` value:
  /// `0.8` → `"0.8"`, `1.0` → `"1"`, `0.96` → `"0.96"`.
  static String formatRating(double rating) {
    final double clamped = rating.isFinite ? rating.clamp(0.0, 1.0) : 0.0;
    if (clamped == 0) {
      return '0';
    }
    final String fixed = clamped.toStringAsFixed(4);
    final String trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Parses a `rating` tag value into `0..1`, or `null` when it is missing or
  /// not a finite number.
  static double? parseRating(Object? raw) {
    final double? value = switch (raw) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v.trim()),
      _ => null,
    };
    if (value == null || !value.isFinite) {
      return null;
    }
    return value.clamp(0.0, 1.0);
  }

  /// Builds the tags for a review: place key, rating, client marker, then the
  /// full geohash and every one of its prefixes.
  static List<List<String>> buildTags({
    required String placeKey,
    required double rating,
    required LatLon position,
  }) {
    final String hash = Geohash.encode(
      position.latitude,
      position.longitude,
      precision: fullGeohashPrecision,
    );
    return <List<String>>[
      <String>['d', placeKey],
      <String>['rating', formatRating(rating)],
      <String>['client', clientName],
      for (final String prefix in Geohash.prefixes(
        hash,
        minPrecision: shortestGeohashPrecision,
      ))
        <String>['g', prefix],
    ];
  }

  /// The event content: the review text, then any photo links on their own
  /// lines (the usual way images are embedded on Nostr).
  static String composeContent({
    required String text,
    List<String> photoUrls = const <String>[],
  }) {
    final String body = text.trim();
    final List<String> links = <String>[
      for (final String url in photoUrls.take(maxPhotoLinks)) url.trim(),
    ].where((String url) => url.isNotEmpty).toList(growable: false);
    if (links.isEmpty) {
      return body;
    }
    final String joined = links.join('\n');
    return body.isEmpty ? joined : '$body\n\n$joined';
  }

  /// All image links found in [content] (Blossom links and plain image URLs).
  static List<String> photosIn(String content) {
    final RegExp urlPattern = RegExp(r'https?://[^\s<>()]+');
    final List<String> photos = <String>[];
    for (final RegExpMatch match in urlPattern.allMatches(content)) {
      final String url = _trimUrl(match.group(0)!);
      if (url.isEmpty || !_looksLikeImage(url) || photos.contains(url)) {
        continue;
      }
      photos.add(url);
      if (photos.length >= maxPhotoLinks) {
        break;
      }
    }
    return photos;
  }

  /// Parses a Nostr event into a [Review], or `null` when it is not a valid
  /// review. Every field is treated as hostile: wrong kinds, missing `d`/`g`/
  /// `rating` tags, out-of-range values and oversized payloads are dropped.
  static Review? fromEvent(Nip01Event event) {
    if (event.kind != kind) {
      return null;
    }
    final String id = event.id.trim();
    final String pubkey = event.pubKey.trim().toLowerCase();
    if (id.isEmpty || !_hex64.hasMatch(pubkey)) {
      return null;
    }
    final String rawContent = event.content;
    if (rawContent.length > maxContentLength) {
      return null;
    }

    String? placeKey;
    double? rating;
    final List<String> geohashes = <String>[];
    for (final List<String> tag in event.tags) {
      if (tag.length < 2) {
        continue;
      }
      final String name = tag[0];
      final String value = tag[1].trim();
      switch (name) {
        case 'd':
          if (value.isNotEmpty && value.length <= maxPlaceKeyLength) {
            placeKey ??= value;
          }
        case 'rating':
          rating ??= parseRating(value);
        case 'g':
          if (value.isNotEmpty &&
              value.length <= Geohash.maxPrecision &&
              geohashes.length < 32) {
            geohashes.add(value.toLowerCase());
          }
      }
    }
    final String? key = placeKey;
    final double? normalized = rating;
    if (key == null || normalized == null || geohashes.isEmpty) {
      return null;
    }

    // The longest valid geohash is the most precise point we can recover.
    geohashes.sort((String a, String b) => b.length.compareTo(a.length));
    LatLon? position;
    for (final String hash in geohashes) {
      final GeoCenter? center = Geohash.tryDecode(hash);
      if (center == null) {
        continue;
      }
      position = LatLon.tryParse(center.latitude, center.longitude);
      if (position != null) {
        break;
      }
    }
    if (position == null) {
      return null;
    }

    final int createdAt = event.createdAt;
    return Review(
      id: id,
      authorPubkey: pubkey,
      placeKey: key,
      rating: normalized,
      content: rawContent,
      position: position,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAt > 0 ? createdAt * 1000 : 0,
        isUtc: true,
      ),
      photos: photosIn(rawContent),
    );
  }

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  static final RegExp _imagePath = RegExp(
    r'\.(jpe?g|png|gif|webp|avif|heic|bmp)(\?.*)?$',
    caseSensitive: false,
  );
  static final RegExp _sha256InPath = RegExp(r'/([a-fA-F0-9]{64})(?:/|$)');

  static bool _looksLikeImage(String url) {
    if (_sha256InPath.hasMatch(url)) {
      return true;
    }
    return _imagePath.hasMatch(url.split('#').first);
  }

  static String _trimUrl(String raw) {
    String url = raw.trim();
    while (url.isNotEmpty && '.,;:!?)]}'.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    return url.length > 2048 ? '' : url;
  }
}
