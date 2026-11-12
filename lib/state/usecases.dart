import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/browse_category.dart';
import '../domain/usecases/check_for_update.dart';
import '../domain/usecases/load_reviews.dart';
import '../domain/usecases/publish_review.dart';
import '../domain/usecases/request_route.dart';
import '../domain/usecases/request_stop_departures.dart';
import '../domain/usecases/request_stop_info.dart';
import '../domain/usecases/request_transit_route.dart';
import '../domain/usecases/request_transit_trip.dart';
import '../domain/usecases/search_places.dart';
import '../domain/usecases/toggle_bookmark.dart';
import '../domain/usecases/watch_location.dart';
import 'ports.dart';

/// Use-case providers: each composes a port with the domain use case that
/// validates and invokes it. Notifiers depend on these, never on ports directly.
final Provider<SearchPlaces> searchPlacesProvider = Provider<SearchPlaces>(
  (Ref ref) => SearchPlaces(ref.watch(searchServiceProvider)),
);

final Provider<BrowseCategory> browseCategoryProvider =
    Provider<BrowseCategory>(
      (Ref ref) => BrowseCategory(ref.watch(searchServiceProvider)),
    );

final Provider<RequestRoute> requestRouteProvider = Provider<RequestRoute>(
  (Ref ref) => RequestRoute(ref.watch(routingServiceProvider)),
);

/// Plans a public-transport journey through the transit port (Transitous).
final Provider<RequestTransitRoute> requestTransitRouteProvider =
    Provider<RequestTransitRoute>(
      (Ref ref) =>
          RequestTransitRoute(ref.watch(transitRoutingServiceProvider)),
    );

/// Reads the next departures from a stop (the "Departures" board).
final Provider<RequestStopDepartures> requestStopDeparturesProvider =
    Provider<RequestStopDepartures>(
      (Ref ref) =>
          RequestStopDepartures(ref.watch(transitRoutingServiceProvider)),
    );

/// Reads one stop's static information (id, name, lines) for a station sheet.
final Provider<RequestStopInfo> requestStopInfoProvider =
    Provider<RequestStopInfo>(
      (Ref ref) => RequestStopInfo(ref.watch(transitRoutingServiceProvider)),
    );

/// Reads one trip's full shape (line drawing on the map).
final Provider<RequestTransitTrip> requestTransitTripProvider =
    Provider<RequestTransitTrip>(
      (Ref ref) => RequestTransitTrip(ref.watch(transitRoutingServiceProvider)),
    );

final Provider<WatchLocation> watchLocationProvider = Provider<WatchLocation>(
  (Ref ref) => WatchLocation(ref.watch(locationServiceProvider)),
);

final Provider<ToggleBookmark> toggleBookmarkProvider =
    Provider<ToggleBookmark>(
      (Ref ref) => ToggleBookmark(ref.watch(placesRepositoryProvider)),
    );

final Provider<PublishReview> publishReviewProvider = Provider<PublishReview>(
  (Ref ref) => PublishReview(ref.watch(reviewServiceProvider)),
);

final Provider<LoadPlaceReviews> loadPlaceReviewsProvider =
    Provider<LoadPlaceReviews>(
      (Ref ref) => LoadPlaceReviews(ref.watch(reviewServiceProvider)),
    );

final Provider<LoadVisibleReviews> loadVisibleReviewsProvider =
    Provider<LoadVisibleReviews>(
      (Ref ref) => LoadVisibleReviews(ref.watch(reviewServiceProvider)),
    );

/// Reads the installed version and the latest advertised release (self-update).
final Provider<CheckForUpdate> checkForUpdateProvider =
    Provider<CheckForUpdate>(
      (Ref ref) => CheckForUpdate(
        ref.watch(appVersionSourceProvider),
        ref.watch(releaseSourceProvider),
      ),
    );
