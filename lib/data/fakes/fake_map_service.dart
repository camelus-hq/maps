import 'dart:async';
import 'dart:math' as math;

import '../../domain/entities/camera.dart';
import '../../domain/entities/friend_marker.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/map_style.dart';
import '../../domain/entities/marker.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/review_marker.dart';
import '../../domain/entities/route_line.dart';
import '../../domain/entities/transit_stop_marker.dart';
import '../../domain/ports/map_service.dart';
import 'sample_data.dart';

/// In-memory [MapService]; the real Mapbox adapter lives in `data/mapbox/`.
class FakeMapService implements MapService {
  FakeMapService({Camera? initialCamera})
    : _camera = initialCamera ?? const Camera(target: SampleData.origin);

  final StreamController<Camera> _cameraController =
      StreamController<Camera>.broadcast();
  final StreamController<LatLon> _tapController =
      StreamController<LatLon>.broadcast();
  final StreamController<LatLon> _longPressController =
      StreamController<LatLon>.broadcast();
  final StreamController<String> _markerTapController =
      StreamController<String>.broadcast();
  final StreamController<Place> _poiTapController =
      StreamController<Place>.broadcast();
  final StreamController<void> _userGestureController =
      StreamController<void>.broadcast();
  final StreamController<String> _friendMarkerTapController =
      StreamController<String>.broadcast();
  final StreamController<String> _reviewMarkerTapController =
      StreamController<String>.broadcast();
  Camera _camera;
  List<Marker> _markers = const <Marker>[];
  List<Marker> _savedMarkers = const <Marker>[];
  List<FriendMarker> _friendMarkers = const <FriendMarker>[];
  List<ReviewMarker> _reviewMarkers = const <ReviewMarker>[];
  List<RouteLine> _routeLines = const <RouteLine>[];
  List<TransitStopMarker> _transitStopMarkers = const <TransitStopMarker>[];
  BaseMapStyle _baseStyle = BaseMapStyle.standard;
  bool _traffic = false;

  @override
  Camera get camera => _camera;

  @override
  Stream<Camera> get cameraStream => _cameraController.stream;

  @override
  List<Marker> get markers => _markers;

  @override
  List<Marker> get savedMarkers => _savedMarkers;

  @override
  List<FriendMarker> get friendMarkers => _friendMarkers;

  @override
  Stream<String> get friendMarkerTapStream => _friendMarkerTapController.stream;

  @override
  List<ReviewMarker> get reviewMarkers => _reviewMarkers;

  @override
  Stream<String> get reviewMarkerTapStream => _reviewMarkerTapController.stream;

  /// The current base style (for tests and the control channel).
  BaseMapStyle get baseStyle => _baseStyle;

  /// Whether the traffic overlay is on (for tests/control channel).
  bool get trafficEnabled => _traffic;

  @override
  Stream<LatLon> get tapStream => _tapController.stream;

  @override
  Stream<LatLon> get longPressStream => _longPressController.stream;

  @override
  Stream<String> get markerTapStream => _markerTapController.stream;

  @override
  Stream<Place> get poiTapStream => _poiTapController.stream;

  @override
  Stream<void> get userGestureStream => _userGestureController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> moveCamera(
    Camera camera, {
    bool animated = false,
    Duration? duration,
  }) async {
    _camera = camera;
    if (!_cameraController.isClosed) {
      _cameraController.add(camera);
    }
  }

  @override
  Future<void> setMarkers(List<Marker> markers) async {
    _markers = List<Marker>.unmodifiable(markers);
  }

  @override
  Future<void> setSavedMarkers(List<Marker> markers) async {
    _savedMarkers = List<Marker>.unmodifiable(markers);
  }

  @override
  Future<void> setFriendMarkers(List<FriendMarker> markers) async {
    _friendMarkers = List<FriendMarker>.unmodifiable(markers);
  }

  @override
  Future<void> setReviewMarkers(List<ReviewMarker> markers) async {
    _reviewMarkers = List<ReviewMarker>.unmodifiable(markers);
  }

  @override
  Future<void> setBaseStyle(BaseMapStyle style) async {
    _baseStyle = style;
  }

  @override
  Future<void> setTrafficEnabled(bool enabled) async {
    _traffic = enabled;
  }

  @override
  Future<void> setRouteLines(List<RouteLine> lines) async {
    _routeLines = <RouteLine>[
      for (final RouteLine line in lines)
        RouteLine(
          points: List<LatLon>.unmodifiable(line.points),
          color: line.color,
          dashed: line.dashed,
          width: line.width,
          primary: line.primary,
        ),
    ];
  }

  @override
  List<RouteLine> get routeLines => _routeLines;

  @override
  Future<void> setTransitStopMarkers(List<TransitStopMarker> markers) async {
    _transitStopMarkers = List<TransitStopMarker>.unmodifiable(markers);
  }

  @override
  List<TransitStopMarker> get transitStopMarkers => _transitStopMarkers;

  @override
  Future<void> fitCoordinates(List<LatLon> points) async {
    if (points.isEmpty) {
      return;
    }
    double minLat = points.first.latitude;
    double maxLat = minLat;
    double minLon = points.first.longitude;
    double maxLon = minLon;
    for (final LatLon point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    final LatLon center = LatLon((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    final double span = math.max(maxLat - minLat, maxLon - minLon);
    // A single point (or coincident ones) has no span; use the same maximum the
    // real Mapbox adapter caps a fit at, so a lone result reads as a
    // neighbourhood rather than a doorstep.
    final double zoom = span <= 0
        ? 16
        : (math.log(360 / span) / math.ln2 + 0.5).clamp(3.0, 16.0);
    await moveCamera(Camera(target: center, zoom: zoom));
  }

  /// Injects a tap, for tests and the control channel.
  void emitTap(LatLon position) {
    if (!_tapController.isClosed) {
      _tapController.add(position);
    }
  }

  /// Injects a long-press, for tests and the control channel.
  void emitLongPress(LatLon position) {
    if (!_longPressController.isClosed) {
      _longPressController.add(position);
    }
  }

  /// Injects a result-marker tap, for tests and the control channel.
  void emitMarkerTap(String id) {
    if (!_markerTapController.isClosed) {
      _markerTapController.add(id);
    }
  }

  /// Injects a map POI tap, for tests and the control channel.
  void emitPoiTap(Place place) {
    if (!_poiTapController.isClosed) {
      _poiTapController.add(place);
    }
  }

  /// Injects a friend-marker tap (by public key), for tests and the control
  /// channel.
  void emitFriendMarkerTap(String pubkey) {
    if (!_friendMarkerTapController.isClosed) {
      _friendMarkerTapController.add(pubkey);
    }
  }

  /// Injects a review-badge tap (by place key), for tests and the control
  /// channel.
  void emitReviewMarkerTap(String placeKey) {
    if (!_reviewMarkerTapController.isClosed) {
      _reviewMarkerTapController.add(placeKey);
    }
  }

  /// Injects a user map gesture (drag/zoom/rotate/tilt), for tests and the
  /// control channel — the same signal the real map emits on a pan.
  void emitUserGesture() {
    if (!_userGestureController.isClosed) {
      _userGestureController.add(null);
    }
  }

  /// Releases the broadcast controllers.
  void dispose() {
    unawaited(_cameraController.close());
    unawaited(_tapController.close());
    unawaited(_longPressController.close());
    unawaited(_markerTapController.close());
    unawaited(_poiTapController.close());
    unawaited(_userGestureController.close());
    unawaited(_friendMarkerTapController.close());
    unawaited(_reviewMarkerTapController.close());
  }
}
