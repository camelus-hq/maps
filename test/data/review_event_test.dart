import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/entities.dart' show Nip01Event;
import 'package:openmaps/core/utils/geohash.dart';
import 'package:openmaps/data/nostr/review_event.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/review.dart';
import 'package:openmaps/domain/entities/review_place.dart';

/// The review event codec is the wire format of the whole feature: the tags it
/// writes are what a relay indexes, and the parser has to treat every field as
/// hostile (AGENTS.md "Never crash").
void main() {
  const String author =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const LatLon berlin = LatLon(52.5195, 13.4120);
  final String placeKey = ReviewPlace.keyFor('way/123456');

  Nip01Event event({
    int kind = ReviewEvent.kind,
    String pubKey = author,
    List<List<String>> tags = const <List<String>>[],
    String content = 'good food',
    int createdAt = 1700000000,
  }) => Nip01Event(
    pubKey: pubKey,
    kind: kind,
    tags: tags,
    content: content,
    createdAt: createdAt,
  );

  List<List<String>> tagsFor({double rating = 0.8, LatLon at = berlin}) =>
      ReviewEvent.buildTags(placeKey: placeKey, rating: rating, position: at);

  group('place keys', () {
    test('keyFor normalises known prefixes', () {
      expect(ReviewPlace.keyFor('way/1'), 'openstreetmap:way/1');
      expect(ReviewPlace.keyFor('osm:way/1'), 'openstreetmap:way/1');
      expect(ReviewPlace.keyFor('openstreetmap:way/1'), 'openstreetmap:way/1');
    });

    test('keyFor decodes a Mapbox-encoded OSM feature id', () {
      // Regression: the d tag used to carry the encoded value, one digit long.
      expect(
        ReviewPlace.keyFor('27640507620'),
        'openstreetmap:node/2764050762',
      );
      expect(ReviewPlace.keyFor('27640507621'), 'openstreetmap:way/2764050762');
      expect(
        ReviewPlace.keyFor('27640507624'),
        'openstreetmap:relation/2764050762',
      );
      // An id that already names the element is left alone.
      expect(
        ReviewPlace.keyFor('node/2764050762'),
        'openstreetmap:node/2764050762',
      );
      // A provider-internal id (no OSM id) is kept verbatim.
      expect(ReviewPlace.keyFor('poi.123'), 'openstreetmap:poi.123');
      expect(ReviewPlace.keyFor(''), 'openstreetmap:');
    });

    test('isValidKey bounds the id', () {
      expect(ReviewPlace.isValidKey('openstreetmap:way/1'), isTrue);
      expect(ReviewPlace.isValidKey('openstreetmap:node/2764050762'), isTrue);
      expect(ReviewPlace.isValidKey('way/1'), isFalse);
      expect(ReviewPlace.isValidKey('openstreetmap:'), isFalse);
      expect(ReviewPlace.isValidKey('openstreetmap:${'x' * 400}'), isFalse);
    });
  });

  group('tags', () {
    test('carry d, rating, client and the nested geohash prefixes', () {
      final List<List<String>> tags = tagsFor();
      expect(tags.first, <String>['d', placeKey]);
      expect(
        tags.firstWhere((List<String> tag) => tag.first == 'rating'),
        equals(<String>['rating', '0.8']),
      );
      expect(
        tags.firstWhere((List<String> tag) => tag.first == 'client'),
        equals(<String>['client', 'openmaps']),
      );

      final List<String> geohashes = <String>[
        for (final List<String> tag in tags)
          if (tag.first == 'g') tag[1],
      ];
      final String full = Geohash.encode(
        berlin.latitude,
        berlin.longitude,
        precision: ReviewEvent.fullGeohashPrecision,
      );
      expect(geohashes.first, full);
      expect(geohashes, Geohash.prefixes(full));
      // Full precision down to a single character.
      expect(geohashes.last.length, 1);
      expect(geohashes.length, full.length);
    });

    test('formatRating keeps a compact numeric string', () {
      expect(ReviewEvent.formatRating(0.8), '0.8');
      expect(ReviewEvent.formatRating(1), '1');
      expect(ReviewEvent.formatRating(0.96), '0.96');
      expect(ReviewEvent.formatRating(0), '0');
      expect(ReviewEvent.formatRating(2), '1');
      expect(ReviewEvent.formatRating(double.nan), '0');
    });

    test('parseRating clamps and rejects junk', () {
      expect(ReviewEvent.parseRating('0.8'), 0.8);
      expect(ReviewEvent.parseRating('2'), 1.0);
      expect(ReviewEvent.parseRating('-1'), 0.0);
      expect(ReviewEvent.parseRating('nope'), isNull);
      expect(ReviewEvent.parseRating(null), isNull);
      expect(ReviewEvent.parseRating(double.infinity), isNull);
    });
  });

  group('content', () {
    test('appends photo links after the text', () {
      expect(
        ReviewEvent.composeContent(
          text: 'good food',
          photoUrls: <String>['https://blossom.example/a'],
        ),
        'good food\n\nhttps://blossom.example/a',
      );
      expect(
        ReviewEvent.composeContent(
          text: '   ',
          photoUrls: <String>['https://blossom.example/a'],
        ),
        'https://blossom.example/a',
      );
      expect(ReviewEvent.composeContent(text: 'good food'), 'good food');
    });

    test('photosIn picks image links and ignores the rest', () {
      final String sha = 'b' * 64;
      final String content =
          'loved it\n\nhttps://blossom.example/$sha\n'
          'https://example.com/page\nhttps://cdn.example/photo.jpg';
      final List<String> photos = ReviewEvent.photosIn(content);
      expect(photos, hasLength(2));
      expect(photos.first, 'https://blossom.example/$sha');
      expect(photos.last, 'https://cdn.example/photo.jpg');
    });
  });

  group('fromEvent', () {
    test('round-trips a valid review', () {
      final Review? review = ReviewEvent.fromEvent(
        event(
          tags: tagsFor(rating: 0.96),
          content: 'Beautiful acoustics. Book the balcony seats!',
        ),
      );
      expect(review, isNotNull);
      expect(review!.authorPubkey, author);
      expect(review.placeKey, placeKey);
      expect(review.rating, closeTo(0.96, 1e-9));
      expect(review.stars, closeTo(4.8, 1e-9));
      expect(review.roundedStars, 5);
      expect(review.position.latitude, closeTo(berlin.latitude, 0.0001));
      expect(review.photos, isEmpty);
      expect(review.createdAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('separates photo links from the body text', () {
      final String sha = 'c' * 64;
      final Review? review = ReviewEvent.fromEvent(
        event(
          tags: tagsFor(),
          content: 'good food\n\nhttps://blossom.example/$sha',
        ),
      );
      expect(review, isNotNull);
      expect(review!.photos, <String>['https://blossom.example/$sha']);
      expect(review.bodyText, 'good food');
    });

    test('drops events it cannot trust', () {
      expect(ReviewEvent.fromEvent(event(kind: 1, tags: tagsFor())), isNull);
      // No d tag.
      expect(
        ReviewEvent.fromEvent(
          event(
            tags: <List<String>>[
              <String>['rating', '0.8'],
              <String>['g', 'u33d'],
            ],
          ),
        ),
        isNull,
      );
      // No usable geohash.
      expect(
        ReviewEvent.fromEvent(
          event(
            tags: <List<String>>[
              <String>['d', placeKey],
              <String>['rating', '0.8'],
              <String>['g', '!!!'],
            ],
          ),
        ),
        isNull,
      );
      // No rating.
      expect(
        ReviewEvent.fromEvent(
          event(
            tags: <List<String>>[
              <String>['d', placeKey],
              <String>['g', 'u33d'],
            ],
          ),
        ),
        isNull,
      );
      // Bad author key.
      expect(
        ReviewEvent.fromEvent(event(pubKey: 'not-a-key', tags: tagsFor())),
        isNull,
      );
      // Oversized content.
      expect(
        ReviewEvent.fromEvent(
          event(
            tags: tagsFor(),
            content: 'x' * (ReviewEvent.maxContentLength + 1),
          ),
        ),
        isNull,
      );
    });

    test('keeps a valid geohash among invalid ones', () {
      final Review? review = ReviewEvent.fromEvent(
        event(
          tags: <List<String>>[
            <String>['d', placeKey],
            <String>['rating', '0.4'],
            <String>['g', '!!!!'],
            <String>['g', 'u33dc0yk6'],
          ],
        ),
      );
      expect(review, isNotNull);
      expect(review!.position.latitude, closeTo(52.52, 0.01));
    });
  });
}
