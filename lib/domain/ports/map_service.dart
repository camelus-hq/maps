import '../entities/camera.dart';
import '../entities/friend_marker.dart';
import '../entities/lat_lon.dart';
import '../entities/map_style.dart';
import '../entities/marker.dart';
import '../entities/place.dart';
import '../entities/review_marker.dart';
import '../entities/route_line.dart';
import '../entities/transit_stop_marker.dart';

/// Renders the map and owns camera/gesture/marker state.
///
/// Implemented in `data/` by the Mapbox adapter and by an in-memory fake for
/// tests and keyless runs.
abstract interface class MapService {
  /// Prepares the underlying map engine.
  Future<void> initialize();

  /// Emits the current camera whenever it changes.
  Stream<Camera> get cameraStream;

  Camera get camera;

  /// Emits each time the user drives the camera with a map gesture (pan, zoom,
  /// rotate or tilt).
  ///
  /// Programmatic moves ([moveCamera], [fitCoordinates]) never emit here, so
  /// the state layer can tell "the user took the map" from "we moved it" and
  /// drop location follow / guidance tracking instead of yanking the camera
  /// back on the next position fix.
  Stream<void> get userGestureStream;

  /// Moves the camera (programmatic navigation, follow mode, animations).
  /// [animated] eases to the target instead of jumping; [duration] overrides
  /// the default animation length (used by location follow to glide between
  /// fixes at the fix cadence instead of stepping).
  Future<void> moveCamera(
    Camera camera, {
    bool animated = false,
    Duration? duration,
  });

  /// Fits the camera to the given points (search results, route, …).
  Future<void> fitCoordinates(List<LatLon> points);

  /// Draws styled route polylines (street routes or public-transport legs).
  /// An empty list clears them.
  Future<void> setRouteLines(List<RouteLine> lines);

  /// The route polylines currently drawn.
  List<RouteLine> get routeLines;

  /// Replaces the visible markers.
  Future<void> setMarkers(List<Marker> markers);

  /// The currently visible markers.
  List<Marker> get markers;

  /// Switches the base map style (layers switcher).
  Future<void> setBaseStyle(BaseMapStyle style);

  /// Enables/disables the realtime traffic overlay on top of the base style.
  Future<void> setTrafficEnabled(bool enabled);

  /// Replaces the saved-place (star) markers, drawn separately from [markers].
  Future<void> setSavedMarkers(List<Marker> markers);

  /// The currently visible saved-place markers.
  List<Marker> get savedMarkers;

  /// Replaces the live-location friend markers (badge + name label), drawn on
  /// their own layer so they never mix with search results or saved places.
  Future<void> setFriendMarkers(List<FriendMarker> markers);

  /// The currently visible friend markers.
  List<FriendMarker> get friendMarkers;

  /// Emits the friend's public key each time one of their markers is tapped.
  Stream<String> get friendMarkerTapStream;

  /// Replaces the review badges (one per reviewed place on screen), drawn on
  /// their own layer so they never mix with friend pins or search results.
  Future<void> setReviewMarkers(List<ReviewMarker> markers);

  /// The review badges currently drawn.
  List<ReviewMarker> get reviewMarkers;

  /// Emits the place key each time a review badge is tapped.
  Stream<String> get reviewMarkerTapStream;

  /// Replaces the transit stop circles drawn for a public-transport journey
  /// (small pass-through dots and larger boarding/alighting circles), on their
  /// own layer so they never mix with search pins or saved places.
  Future<void> setTransitStopMarkers(List<TransitStopMarker> markers);

  /// The transit stop circles currently drawn.
  List<TransitStopMarker> get transitStopMarkers;

  /// Emits the coordinate each time the map surface is tapped (feeds the
  /// place flow in M3).
  Stream<LatLon> get tapStream;

  /// Emits the coordinate each time the map surface is long-pressed (used to
  /// pick departure/arrival points).
  Stream<LatLon> get longPressStream;

  /// Emits the id of a result marker the user tapped (the places drawn by
  /// [setMarkers]); the place flow opens its details.
  Stream<String> get markerTapStream;

  /// Emits a point of interest the user tapped on the map (a POI drawn by the
  /// map style) so its details can be shown without moving the camera.
  Stream<Place> get poiTapStream;
}
