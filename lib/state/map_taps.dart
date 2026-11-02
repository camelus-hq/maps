import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/place.dart';
import '../domain/ports/map_service.dart';
import 'commands/commands_provider.dart';
import 'place.dart';
import 'ports.dart';
import 'social.dart';

/// Routes taps on the map into the place flow.
///
/// - A tapped **result marker** (drawn by `setMarkers`) selects that place via
///   the `place.select` command. The camera stays put (the pin is already on
///   screen), the other pins remain visible, and the tapped pin is highlighted.
/// - A tapped **map POI** (the restaurant/shop icons drawn by the map style)
///   opens its details without moving the camera — matching Google Maps.
/// - A tapped **friend badge** (a live-location friend) opens their location
///   sheet instead of a place.
/// - A tapped **review badge** (a reviewed place) opens that place's details,
///   where the reviews live.
///
/// Kept alive by the map home; the subscriptions are cancelled on dispose.
class MapTapController extends Notifier<void> {
  @override
  void build() {
    final MapService map = ref.read(mapServiceProvider);
    final StreamSubscription<String> markerSub = map.markerTapStream.listen(
      (String id) => unawaited(
        ref.read(commandRegistryProvider).dispatch(
          'place.select',
          // The pin is already on screen, so keep the camera where it is.
          <String, Object?>{'id': id, 'focus': false},
        ),
      ),
    );
    final StreamSubscription<Place> poiSub = map.poiTapStream.listen((
      Place place,
    ) {
      ref.read(selectedFriendProvider.notifier).clear();
      ref.read(selectedPlaceProvider.notifier).select(place);
    });
    final StreamSubscription<String> friendSub = map.friendMarkerTapStream
        .listen(
          (String pubkey) => unawaited(
            ref.read(commandRegistryProvider).dispatch(
              'social.friend.select',
              // The pin is on screen already, so leave the camera alone.
              <String, Object?>{'pubkey': pubkey, 'focus': false},
            ),
          ),
        );
    final StreamSubscription<String> reviewSub = map.reviewMarkerTapStream
        .listen(
          (String placeKey) => unawaited(
            ref.read(commandRegistryProvider).dispatch(
              'review.open',
              <String, Object?>{'placeKey': placeKey, 'focus': false},
            ),
          ),
        );
    ref.onDispose(() {
      unawaited(markerSub.cancel());
      unawaited(poiSub.cancel());
      unawaited(friendSub.cancel());
      unawaited(reviewSub.cancel());
    });
  }
}

final NotifierProvider<MapTapController, void> mapTapProvider =
    NotifierProvider<MapTapController, void>(MapTapController.new);
