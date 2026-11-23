import 'dart:async';

import 'package:ndk/entities.dart'
    show NdkFile, Nip01Event, RelayBroadcastResponse;
import 'package:ndk/ndk.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_bounds.dart';
import '../../domain/entities/review_bounds_cover.dart';
import '../../domain/entities/review_draft.dart';
import '../../domain/ports/review_service.dart';
import 'review_event.dart';

/// [ReviewService] backed by Nostr (kind 31987) and Blossom, through NDK.
///
/// Publishing signs a parameterised replaceable event whose `d` tag is the
/// place key and whose `g` tags carry the point's geohash at every precision.
/// Reading the map asks for the geohash cells covering the **visible** bounds,
/// so a relay answers with only what is on screen; a very wide viewport falls
/// back to a plain kind query (the honest "for now" path) and the caller still
/// clips the result to the viewport.
///
/// Photos are uploaded to Blossom first and their URLs are embedded in the
/// review's content, as is usual on Nostr.
class NdkReviewService implements ReviewService {
  NdkReviewService({
    required this.ndk,
    List<String> relays = const <String>[],
    List<String> blossomServers = const <String>[],
  }) : _relays = _cleanRelays(relays),
       _blossomServers = _cleanServers(blossomServers);

  /// Timeout for one broadcast, so a dead relay cannot hang a publish forever.
  static const Duration _broadcastTimeout = Duration(seconds: 12);

  /// Timeout for one relay read.
  static const Duration _queryTimeout = Duration(seconds: 8);

  /// A query never returns more than this many events.
  static const int _queryLimit = 500;

  final Ndk ndk;
  final List<String> _relays;
  final List<String> _blossomServers;

  @override
  bool get isLoggedIn => ndk.accounts.isLoggedIn;

  @override
  String? get currentUserPubkey => ndk.accounts.getPublicKey();

  @override
  Future<void> publishReview(ReviewDraft draft) async {
    final String? me = currentUserPubkey;
    final Account? account = ndk.accounts.getLoggedAccount();
    if (me == null || account == null || !account.signer.canSign()) {
      throw const ValidationException('Sign in to publish a review');
    }
    if (!ReviewEvent.isPlaceKey(draft.placeKey)) {
      throw const ValidationException('This place cannot be reviewed');
    }
    final List<String> photoUrls = await uploadPhotos(draft.photos);
    final String content = ReviewEvent.composeContent(
      text: draft.text,
      photoUrls: <String>[...draft.photoUrls, ...photoUrls],
    );
    final Nip01Event event = Nip01Event(
      pubKey: me,
      kind: ReviewEvent.kind,
      tags: ReviewEvent.buildTags(
        placeKey: draft.placeKey,
        rating: draft.rating,
        position: draft.position,
        priceAmount: draft.priceAmount,
        priceCurrency: draft.priceCurrency,
      ),
      content: content,
    );
    final Nip01Event signed;
    try {
      signed = await account.signer.sign(event);
    } catch (error) {
      throw UnknownException('Could not sign your review', cause: error);
    }
    final bool delivered = await _broadcast(signed, account);
    if (!delivered) {
      throw const NetworkException(
        'Could not reach the relay network. Check your connection and try '
        'again.',
      );
    }
  }

  @override
  Future<List<Review>> reviewsForPlace(String placeKey) async {
    final List<Nip01Event> events = await _safeQuery(
      name: 'openmaps-place-reviews',
      filter: Filter(
        kinds: <int>[ReviewEvent.kind],
        tags: <String, List<String>>{
          '#d': <String>[placeKey],
        },
        limit: _queryLimit,
      ),
    );
    return _toReviews(events);
  }

  @override
  Future<List<Review>> reviewsInBounds(ReviewBounds bounds) async {
    final ReviewBoundsCover? cover = ReviewBoundsCover.of(bounds);
    final List<Nip01Event> events = cover == null
        // Too wide to cover with tags: read the kind; the caller clips.
        ? await _safeQuery(
            name: 'openmaps-reviews-all',
            filter: Filter(kinds: <int>[ReviewEvent.kind], limit: _queryLimit),
          )
        : await _safeQuery(
            name: 'openmaps-reviews-bounds',
            filter: Filter(
              kinds: <int>[ReviewEvent.kind],
              tags: <String, List<String>>{'#g': cover.prefixes},
              limit: _queryLimit,
            ),
          );
    // The events are the whole covering cells, not clipped to `bounds`: the map
    // caches them and clips locally (also its defence against a relay that
    // ignores the tag filter), so a pan inside the same cells is served
    // without another relay query.
    return _toReviews(events);
  }

  @override
  Future<List<String>> uploadPhotos(List<ReviewPhoto> photos) async {
    if (photos.isEmpty) {
      return const <String>[];
    }
    final List<String> urls = <String>[];
    for (final ReviewPhoto photo in photos.take(ReviewDraft.maxPhotos)) {
      if (photo.isEmpty) {
        continue;
      }
      try {
        final List<BlobUploadResult> results = await ndk.files
            .upload(
              file: NdkFile(
                data: photo.data,
                mimeType: photo.mimeType,
                size: photo.sizeBytes,
              ),
              serverUrls: _blossomServers.isEmpty ? null : _blossomServers,
              // Blossom uploads must present the signed kind-24242 auth event
              // up front: several public servers answer 400 "missing auth
              // event" rather than a 401, so an on-refusal retry never fires.
              auth: _blossomAuth,
            )
            .timeout(_broadcastTimeout);
        final String? url = _firstUploadedUrl(results);
        if (url != null) {
          urls.add(url);
        }
      } catch (error) {
        throw NetworkException(
          'Could not upload your photo. Try again, or publish without it.',
          cause: error,
        );
      }
    }
    if (urls.isEmpty) {
      throw const NetworkException(
        'Could not upload your photo. Try again, or publish without it.',
      );
    }
    return List<String>.unmodifiable(urls);
  }

  Future<List<Nip01Event>> _safeQuery({
    required String name,
    required Filter filter,
  }) async {
    try {
      return await ndk.requests
          .query(
            name: name,
            filter: filter,
            explicitRelays: _relays.isEmpty ? null : _relays,
            cacheRead: true,
            cacheWrite: true,
            timeout: _queryTimeout,
          )
          .future;
    } catch (error) {
      throw NetworkException('Could not load reviews right now.', cause: error);
    }
  }

  /// Dedupes by event id and parses each event, dropping anything malformed.
  List<Review> _toReviews(List<Nip01Event> events) {
    final Map<String, Review> byId = <String, Review>{};
    for (final Nip01Event event in events) {
      final Review? review = ReviewEvent.fromEvent(event);
      if (review != null) {
        byId[review.id] = review;
      }
    }
    return byId.values.toList(growable: false);
  }

  Future<bool> _broadcast(Nip01Event event, Account account) async {
    try {
      final List<RelayBroadcastResponse> responses = await ndk.broadcast
          .broadcast(
            nostrEvent: event,
            specificRelays: _relays.isEmpty ? null : _relays,
            auth: AuthPolicy.allow(account),
          )
          .broadcastDoneFuture
          .timeout(
            _broadcastTimeout,
            onTimeout: () => const <RelayBroadcastResponse>[],
          );
      return responses.any(
        (RelayBroadcastResponse response) => response.broadcastSuccessful,
      );
    } catch (error) {
      throw NetworkException(
        'Could not reach the relay network. Check your connection and try '
        'again.',
        cause: error,
      );
    }
  }

  /// The auth policy for Blossom uploads: the signed-in account signs the
  /// kind-24242 event up front (public servers answer 400, not 401, without it).
  AuthPolicy? get _blossomAuth {
    final Account? account = ndk.accounts.getLoggedAccount();
    if (account == null || !account.signer.canSign()) {
      return null;
    }
    return AuthPolicy.require(account);
  }

  static String? _firstUploadedUrl(List<BlobUploadResult> results) {
    for (final BlobUploadResult result in results) {
      final String? url = result.success ? result.descriptor?.url : null;
      if (url != null && url.startsWith('http')) {
        return url;
      }
    }
    return null;
  }

  static List<String> _cleanRelays(List<String> relays) {
    final List<String> cleaned = <String>[];
    for (final String raw in relays) {
      final String relay = raw.trim();
      if ((relay.startsWith('wss://') || relay.startsWith('ws://')) &&
          !cleaned.contains(relay)) {
        cleaned.add(relay);
      }
    }
    return cleaned;
  }

  static List<String> _cleanServers(List<String> servers) {
    final List<String> cleaned = <String>[];
    for (final String raw in servers) {
      final String server = raw.trim().replaceAll(RegExp(r'/+$'), '');
      if ((server.startsWith('https://') || server.startsWith('http://')) &&
          !cleaned.contains(server)) {
        cleaned.add(server);
      }
    }
    return cleaned;
  }
}
