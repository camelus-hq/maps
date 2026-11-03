import 'dart:async';
import 'dart:typed_data';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/utils/osm_ref.dart';
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
import 'friend_marker_image.dart';
import 'map_content_gate.dart';
import 'marker_image.dart';
import 'polyline_dashes.dart';
import 'review_marker_image.dart';
import 'transit_stop_marker_image.dart';

/// Real [MapService] backed by the Mapbox Maps SDK.
///
/// Every Mapbox type stays inside `lib/data/mapbox/`; the rest of the app talks
/// in domain [Camera]/[LatLon]. The map widget ([MapboxMapView]) attaches its
/// [MapboxMap] on creation and detaches it on disposal, so calls made while the
/// map is not on screen (e.g. search results while on the search route) are
/// stashed as pending state and replayed on the next attach — never a
/// channel-error crash.
class MapboxMapService implements MapService {
  MapboxMapService({
    required this.accessToken,
    required this.styleUri,
    required Camera initialCamera,
  }) : _camera = initialCamera;

  /// Our own base styles (the M2.3 own-style work is deferred, so these are
  /// Mapbox's stock styles; traffic is an overlay, not a style).
  static const Map<BaseMapStyle, String> _styleUris = <BaseMapStyle, String>{
    BaseMapStyle.standard: 'mapbox://styles/mapbox/standard',
    BaseMapStyle.satellite: 'mapbox://styles/mapbox/satellite-streets-v12',
    BaseMapStyle.terrain: 'mapbox://styles/mapbox/outdoors-v12',
  };

  static const String _trafficSourceId = 'openmaps-traffic';
  static const String _trafficLayerId = 'openmaps-traffic-lines';

  /// Congestion colour ramp for the traffic overlay (our own choices).
  static const List<Object> _trafficColor = <Object>[
    'match',
    <Object>['get', 'congestion'],
    'low',
    '#2e7d32',
    'moderate',
    '#f9a825',
    'heavy',
    '#ef6c00',
    'severe',
    '#c62828',
    '#78909c',
  ];

  static const List<Object> _trafficWidth = <Object>[
    'interpolate',
    <Object>['linear'],
    <Object>['zoom'],
    10,
    2,
    16,
    6,
    18,
    10,
  ];

  final String accessToken;
  String styleUri;

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

  MapboxMap? _map;
  Camera _camera;
  Camera? _pending;
  Camera? _lastEmitted;

  /// Ensures native map mutations (annotations, style layers, the location
  /// puck) only run once the map is attached **and** its style is loaded.
  ///
  /// Before the style loads the native SDK has no annotation-manager registry,
  /// so a call such as `PointAnnotationManager.deleteAll()` throws on the
  /// platform thread — a native crash the Dart `try`/`catch` cannot intercept
  /// ("No manager found with id: 0"). All map content is stashed in the domain
  /// fields and replayed from [onStyleLoaded].
  final MapContentGate _gate = MapContentGate();
  bool _interactionsAdded = false;
  bool _gesturesBound = false;
  final List<StreamSubscription<MapContentGestureContext>> _gestureSubs =
      <StreamSubscription<MapContentGestureContext>>[];
  List<Marker> _markers = const <Marker>[];
  List<Marker> _savedMarkers = const <Marker>[];
  List<FriendMarker> _friendMarkers = const <FriendMarker>[];
  List<ReviewMarker> _reviewMarkers = const <ReviewMarker>[];
  List<RouteLine> _routeLines = const <RouteLine>[];
  List<TransitStopMarker> _transitStops = const <TransitStopMarker>[];
  List<LatLon>? _pendingFit;
  BaseMapStyle _baseStyle = BaseMapStyle.standard;
  bool _darkMode = false;
  bool _traffic = false;
  PointAnnotationManager? _pointManager;
  PointAnnotationManager? _savedPointManager;
  PointAnnotationManager? _friendPointManager;
  PointAnnotationManager? _reviewPointManager;
  PointAnnotationManager? _transitStopManager;
  PolylineAnnotationManager? _lineManager;
  Cancelable? _markerTapCancelable;
  Cancelable? _friendTapCancelable;
  Cancelable? _reviewTapCancelable;
  bool _markerTapBound = false;
  bool _friendTapBound = false;
  bool _reviewTapBound = false;
  final FriendMarkerComposer _friendMarkerComposer = FriendMarkerComposer();
  final ReviewMarkerComposer _reviewMarkerComposer = ReviewMarkerComposer();
  final TransitStopMarkerComposer _transitStopComposer =
      TransitStopMarkerComposer();
  bool _friendAvatarFetchInFlight = false;
  DateTime? _lastMarkerTapAt;
  DateTime? _lastPoiEmitAt;
  Uint8List? _markerImage;
  Uint8List? _markerSelectedImage;
  Uint8List? _starImage;
  Uint8List? _bearingImage;

  /// The style currently selected (the widget reads this when re-created).
  BaseMapStyle get baseStyle => _baseStyle;

  /// Whether the app currently uses its dark theme.
  bool get isDarkMode => _darkMode;

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
  List<ReviewMarker> get reviewMarkers => _reviewMarkers;

  @override
  List<TransitStopMarker> get transitStopMarkers => _transitStops;

  @override
  Stream<String> get friendMarkerTapStream => _friendMarkerTapController.stream;

  @override
  Stream<String> get reviewMarkerTapStream => _reviewMarkerTapController.stream;

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
  Future<void> initialize() async {
    MapboxOptions.setAccessToken(accessToken);
  }

  /// Hands the live [MapboxMap] to the service once the widget is ready.
  void attach(MapboxMap map) {
    _map = map;
    _gate.attached();
    // We render our own compass and scale bar. The native attribution is also
    // hidden: on Android it is glued to the bottom-left of the platform view,
    // under the sheet, so the app draws its own credit above the sheet instead
    // (see `MapAttribution`). The Mapbox logo stays (required by the terms).
    unawaited(
      _guard(() => map.compass.updateSettings(CompassSettings(enabled: false))),
    );
    unawaited(
      _guard(
        () => map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      ),
    );
    unawaited(
      _guard(
        () =>
            map.attribution.updateSettings(AttributionSettings(enabled: false)),
      ),
    );
    if (!_interactionsAdded) {
      // Registered once per map instance: re-adding on every attach would leak
      // native interaction handlers.
      _interactionsAdded = true;
      map.addInteraction(
        TapInteraction.onMap((MapContentGestureContext context) {
          final Position position = context.point.coordinates;
          final LatLon? target = LatLon.tryParse(position.lat, position.lng);
          if (target != null) {
            _emitTap(target);
            unawaited(_emitPoiAt(target));
          }
        }),
      );
      map.addInteraction(
        LongTapInteraction.onMap((MapContentGestureContext context) {
          final Position position = context.point.coordinates;
          final LatLon? target = LatLon.tryParse(position.lat, position.lng);
          if (target != null) {
            _emitLongPress(target);
          }
        }),
      );
      // Standard-style POIs (the restaurant/shop icons drawn by the basemap) are
      // a featureset, not style layers, so they need a typed interaction rather
      // than a rendered-feature query. It does not stop propagation, so tapping
      // one of our own pins that sits over a POI still selects the pin.
      map.addInteraction(
        TapInteraction<StandardPOIs>(
          StandardPOIs(),
          _onPoiFeatureTap,
          radius: 12,
          stopPropagation: false,
        ),
      );
    }
    if (!_gesturesBound) {
      // User-driven camera gestures (drag/pinch/rotate/tilt) are the signal the
      // state layer uses to drop follow/guidance tracking. Bound once per map.
      _gesturesBound = true;
      _bindUserGestures(map);
    }
    final Camera target = _pending ?? _camera;
    _pending = null;
    unawaited(_apply(target));
    // The style-loaded event can fire independently of (and before)
    // `onMapCreated`, so query the current state once: if the style is already
    // ready apply the stashed content now, otherwise [onStyleLoaded] will.
    unawaited(
      _guard(() async {
        if (await map.isStyleLoaded() && identical(_map, map)) {
          onStyleLoaded();
        }
      }),
    );
  }

  /// Called when the map's style has fully loaded — the initial load and every
  /// subsequent style reload. Applies the stashed map content.
  void onStyleLoaded() {
    if (_map == null) {
      return;
    }
    _gate.styleLoaded();
    unawaited(_syncTheme());
    _syncContent();
  }

  /// Updates the Standard style's light preset without reloading the map.
  Future<void> setDarkMode(bool enabled) async {
    if (_darkMode == enabled) {
      return;
    }
    _darkMode = enabled;
    await _syncTheme();
  }

  Future<void> _syncTheme() async {
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen || _baseStyle != BaseMapStyle.standard) {
      return;
    }
    await _guard(
      () => map.setStyleImportConfigProperty(
        'basemap',
        'lightPreset',
        _darkMode ? 'night' : 'day',
      ),
    );
  }

  /// Applies every layer/annotation held in the domain fields to the live map.
  ///
  /// Only safe once the [_gate] is open — annotation managers, style
  /// sources/layers and the location component all need a loaded style.
  void _syncContent() {
    unawaited(_ensureBearingPuck());
    unawaited(setMarkers(_markers));
    unawaited(setSavedMarkers(_savedMarkers));
    unawaited(setFriendMarkers(_friendMarkers));
    unawaited(setReviewMarkers(_reviewMarkers));
    unawaited(setTransitStopMarkers(_transitStops));
    unawaited(setRouteLines(_routeLines));
    unawaited(_syncTraffic());
    final List<LatLon>? pendingFit = _pendingFit;
    if (pendingFit != null) {
      _pendingFit = null;
      unawaited(fitCoordinates(pendingFit));
    }
  }

  /// Subscribes to the native gesture-event streams so a user interaction
  /// (drag, pinch, rotate or tilt) is reported as a [userGestureStream] event.
  void _bindUserGestures(MapboxMap map) {
    final List<Stream<MapContentGestureContext>> events =
        <Stream<MapContentGestureContext>>[
          map.gestures.pan.gestureEvents,
          map.gestures.zoom.gestureEvents,
          map.gestures.rotate.gestureEvents,
          map.gestures.pitch.gestureEvents,
        ];
    for (final Stream<MapContentGestureContext> stream in events) {
      _gestureSubs.add(
        stream.listen(
          (MapContentGestureContext _) => _emitUserGesture(),
          onError: (Object _) {
            // A gesture channel may fail if the map is torn down mid-flight;
            // ignore it — follow/tracking just won't be interrupted by it.
          },
        ),
      );
    }
  }

  void _emitUserGesture() {
    if (!_userGestureController.isClosed) {
      _userGestureController.add(null);
    }
  }

  /// Configures the native location puck, building our heading cone once and
  /// re-applying the settings so the bearing sprite is picked up.
  Future<void> _ensureBearingPuck() async {
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return;
    }
    _bearingImage ??= await buildOriginalHeadingConeImage(argb: 0xFF116B5B);
    await _guard(
      () => map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: 0xFF116B5B,
          showAccuracyRing: true,
          // Rotate the puck by the device heading (magnetometer), not the
          // direction of travel, so the cone points where the phone faces —
          // like Google Maps' heading beam.
          puckBearingEnabled: true,
          puckBearing: PuckBearing.HEADING,
          locationPuck: LocationPuck(
            locationPuck2D: DefaultLocationPuck2D(bearingImage: _bearingImage),
          ),
        ),
      ),
    );
  }

  /// Called when the map widget is disposed (navigating away from the map).
  void detach() {
    _markerTapCancelable?.cancel();
    _friendTapCancelable?.cancel();
    _reviewTapCancelable?.cancel();
    for (final StreamSubscription<MapContentGestureContext> sub
        in _gestureSubs) {
      unawaited(sub.cancel());
    }
    _gestureSubs.clear();
    _gesturesBound = false;
    _map = null;
    _gate.detached();
    _pointManager = null;
    _savedPointManager = null;
    _friendPointManager = null;
    _reviewPointManager = null;
    _transitStopManager = null;
    _lineManager = null;
    _interactionsAdded = false;
    _markerTapBound = false;
    _friendTapBound = false;
    _reviewTapBound = false;
    _markerTapCancelable = null;
    _friendTapCancelable = null;
    _reviewTapCancelable = null;
  }

  @override
  Future<void> moveCamera(Camera camera, {bool animated = false}) async {
    _camera = camera;
    _emitCamera(camera);
    if (_map == null) {
      _pending = camera;
      return;
    }
    await _apply(camera, animated: animated);
  }

  @override
  Future<void> setMarkers(List<Marker> markers) async {
    _markers = List<Marker>.unmodifiable(markers);
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final PointAnnotationManager manager = _pointManager ??= await map
          .annotations
          .createPointAnnotationManager();
      if (!_markerTapBound) {
        // Registered once per map: tapping a drawn marker reports its id.
        _markerTapBound = true;
        _markerTapCancelable = manager.tapEvents(onTap: _onMarkerTap);
      }
      await manager.deleteAll();
      if (_markers.isEmpty) {
        return;
      }
      final Uint8List image = _markerImage ??= await buildOriginalMarkerImage(
        argb: 0xFF116B5B,
      );
      final Uint8List selectedImage = _markerSelectedImage ??=
          await buildOriginalMarkerImage(argb: 0xFF00A98F);
      await manager.createMulti(<PointAnnotationOptions>[
        for (final Marker marker in _markers)
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                marker.position.longitude,
                marker.position.latitude,
              ),
            ),
            image: marker.selected ? selectedImage : image,
            // The pin's tip points at the coordinate.
            iconAnchor: IconAnchor.BOTTOM,

            iconSize: 1,
          ),
      ]);
    } catch (_) {
      // Map disposed mid-flight; state is retained and replayed on attach.
    }
  }

  @override
  Future<void> setSavedMarkers(List<Marker> markers) async {
    _savedMarkers = List<Marker>.unmodifiable(markers);
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final PointAnnotationManager manager = _savedPointManager ??= await map
          .annotations
          .createPointAnnotationManager();
      await manager.deleteAll();
      if (_savedMarkers.isEmpty) {
        return;
      }
      final Uint8List image = _starImage ??= await buildOriginalStarMarkerImage(
        argb: 0xFFF9A825,
      );
      await manager.createMulti(<PointAnnotationOptions>[
        for (final Marker marker in _savedMarkers)
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                marker.position.longitude,
                marker.position.latitude,
              ),
            ),
            image: image,
            iconAnchor: IconAnchor.BOTTOM,
            iconSize: 0.6,
          ),
      ]);
    } catch (_) {
      // Map disposed mid-flight; state is retained and replayed on attach.
    }
  }

  @override
  Future<void> setFriendMarkers(List<FriendMarker> markers) async {
    _friendMarkers = List<FriendMarker>.unmodifiable(markers);
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final PointAnnotationManager manager = _friendPointManager ??= await map
          .annotations
          .createPointAnnotationManager();
      if (!_friendTapBound) {
        // Registered once per map: tapping a friend badge reports their key.
        _friendTapBound = true;
        _friendTapCancelable = manager.tapEvents(onTap: _onFriendTap);
      }
      await manager.deleteAll();
      if (_friendMarkers.isEmpty) {
        return;
      }
      final List<PointAnnotationOptions> options = <PointAnnotationOptions>[];
      for (final FriendMarker marker in _friendMarkers) {
        final Uint8List image = await _friendMarkerComposer.compose(
          label: marker.label,
          pictureUrl: marker.pictureUrl,
          live: marker.live,
        );
        options.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                marker.position.longitude,
                marker.position.latitude,
              ),
            ),
            image: image,
            // The avatar circle sits on the coordinate; the name pill hangs
            // below it (both are part of the drawn image). Tuned so the avatar
            // reads at ~46 logical px, like the reference pin.
            iconAnchor: IconAnchor.CENTER,
            iconSize: 1.1,
          ),
        );
      }
      await manager.createMulti(options);
      unawaited(_loadFriendAvatars(markers));
    } catch (_) {
      // Map disposed mid-flight; state is retained and replayed on attach.
    }
  }

  /// Replaces the review badges (one per reviewed place). A badge for a place
  /// a friend has reviewed is drawn highlighted by the composer.
  @override
  Future<void> setReviewMarkers(List<ReviewMarker> markers) async {
    _reviewMarkers = List<ReviewMarker>.unmodifiable(markers);
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final PointAnnotationManager manager = _reviewPointManager ??= await map
          .annotations
          .createPointAnnotationManager();
      if (!_reviewTapBound) {
        // Registered once per map: tapping a badge reports its place key.
        _reviewTapBound = true;
        _reviewTapCancelable = manager.tapEvents(onTap: _onReviewTap);
      }
      await manager.deleteAll();
      if (_reviewMarkers.isEmpty) {
        return;
      }
      final List<PointAnnotationOptions> options = <PointAnnotationOptions>[];
      for (final ReviewMarker marker in _reviewMarkers) {
        final Uint8List image = await _reviewMarkerComposer.compose(marker);
        options.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                marker.position.longitude,
                marker.position.latitude,
              ),
            ),
            image: image,
            iconAnchor: IconAnchor.BOTTOM,
            // Scaled to ~18 px label (ReviewMarker.onMapScale); the overlap
            // test in the state layer estimates the same size.
            iconSize: ReviewMarker.onMapScale,
          ),
        );
      }
      await manager.createMulti(options);
    } catch (_) {
      // Map disposed mid-flight; state is retained and replayed on attach.
    }
  }

  /// Replaces the transit stop circles (small pass-through dots and larger
  /// boarding/alighting circles) drawn for the selected journey.
  @override
  Future<void> setTransitStopMarkers(List<TransitStopMarker> markers) async {
    _transitStops = List<TransitStopMarker>.unmodifiable(markers);
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final PointAnnotationManager manager = _transitStopManager ??= await map
          .annotations
          .createPointAnnotationManager();
      await manager.deleteAll();
      if (_transitStops.isEmpty) {
        return;
      }
      final List<PointAnnotationOptions> options = <PointAnnotationOptions>[];
      for (final TransitStopMarker marker in _transitStops) {
        final Uint8List image = await _transitStopComposer.compose(marker);
        options.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                marker.position.longitude,
                marker.position.latitude,
              ),
            ),
            image: image,
            // The circle is centred on the coordinate.
            iconAnchor: IconAnchor.CENTER,
            // The composer draws at logical size; the map uses that size.
            iconSize: 1,
          ),
        );
      }
      await manager.createMulti(options);
    } catch (_) {
      // Map disposed mid-flight; state is retained and replayed on attach.
    }
  }

  /// Fetches any missing friend avatars and, when one arrives, repaints the
  /// friend layer so the picture replaces the monogram.
  Future<void> _loadFriendAvatars(List<FriendMarker> markers) async {
    if (_friendAvatarFetchInFlight) {
      return;
    }
    _friendAvatarFetchInFlight = true;
    try {
      bool changed = false;
      for (final FriendMarker marker in markers) {
        final String? url = marker.pictureUrl;
        if (url == null || url.isEmpty) {
          continue;
        }
        if (await _friendMarkerComposer.prefetchAvatar(url)) {
          changed = true;
        }
      }
      if (changed && _map != null && _friendMarkers.isNotEmpty) {
        await setFriendMarkers(_friendMarkers);
      }
    } catch (_) {
      // Avatars are a nicety; the monogram stays.
    } finally {
      _friendAvatarFetchInFlight = false;
    }
  }

  @override
  Future<void> setBaseStyle(BaseMapStyle style) async {
    _baseStyle = style;
    styleUri = _styleUris[style] ?? styleUri;
    final MapboxMap? map = _map;
    if (map == null) {
      return;
    }
    await _guard(() async {
      // The old style's managers/sources/layers are torn down by the reload; a
      // call while the new style is still loading would hit the native
      // "No manager found" crash, so close the gate until the new style settles.
      _gate.styleUnloading();
      await map.loadStyleURI(styleUri);
      _gate.styleLoaded();
      _pointManager = null;
      _savedPointManager = null;
      _friendPointManager = null;
      _reviewPointManager = null;
      _lineManager = null;
      _syncContent();
    });
  }

  @override
  Future<void> setTrafficEnabled(bool enabled) async {
    _traffic = enabled;
    await _syncTraffic();
  }

  /// Adds/removes the traffic overlay for the current map instance.
  Future<void> _syncTraffic() async {
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final bool layerExists = await map.styleLayerExists(_trafficLayerId);
      if (_traffic) {
        if (!await map.styleSourceExists(_trafficSourceId)) {
          await map.addSource(
            VectorSource(
              id: _trafficSourceId,
              url: 'mapbox://mapbox.mapbox-traffic-v1',
            ),
          );
        }
        if (!layerExists) {
          await map.addLayer(
            LineLayer(
              id: _trafficLayerId,
              sourceId: _trafficSourceId,
              sourceLayer: 'traffic',
              lineColorExpression: _trafficColor,
              lineWidthExpression: _trafficWidth,
            ),
          );
        } else {
          await map.setStyleLayerProperty(
            _trafficLayerId,
            'visibility',
            'visible',
          );
        }
      } else if (layerExists) {
        await map.setStyleLayerProperty(_trafficLayerId, 'visibility', 'none');
      }
    } catch (_) {
      // The style may be mid-reload; the next attach/style change resyncs.
    }
  }

  /// The highest zoom a programmatic "fit these places" may use.
  ///
  /// A single result (or two very close ones) otherwise fills the viewport with
  /// a zero-size box, and Mapbox answers with a street-level zoom of ~20 — far
  /// too close to make sense of. Capped at the same level as a single-place
  /// focus, so "water fountain" reads as a neighbourhood, not a doorstep.
  static const double maxFitZoom = 16;

  @override
  Future<void> fitCoordinates(List<LatLon> points) async {
    if (points.isEmpty) {
      return;
    }
    final MapboxMap? map = _map;
    if (map == null) {
      _pendingFit = points;
      return;
    }
    try {
      final CameraOptions fitted = await map.cameraForCoordinates(
        <Point>[
          for (final LatLon point in points)
            Point(coordinates: Position(point.longitude, point.latitude)),
        ],
        MbxEdgeInsets(top: 120, left: 48, bottom: 260, right: 48),
        0,
        0,
      );
      final double fittedZoom = fitted.zoom ?? _camera.zoom;
      final double zoom = fittedZoom.clamp(1.0, maxFitZoom);
      final CameraOptions options = zoom == fittedZoom
          ? fitted
          : CameraOptions(
              center: fitted.center,
              padding: fitted.padding,
              anchor: fitted.anchor,
              zoom: zoom,
              bearing: fitted.bearing,
              pitch: fitted.pitch,
            );
      await map.setCamera(options);
      final Point? center = options.center;
      if (center != null) {
        final LatLon? target = LatLon.tryParse(
          center.coordinates.lat,
          center.coordinates.lng,
        );
        if (target != null) {
          _camera = Camera(
            target: target,
            zoom: options.zoom ?? _camera.zoom,
            bearing: options.bearing ?? 0,
            tilt: options.pitch ?? 0,
          );
          _emitCamera(_camera);
        }
      }
    } catch (_) {
      // Map disposed mid-flight.
    }
  }

  /// Default colour for a [RouteLine] without an explicit one (street routes).
  static const int _defaultLineColor = 0xFF116B5B;

  @override
  Future<void> setRouteLines(List<RouteLine> lines) async {
    _routeLines = lines;
    final MapboxMap? map = _map;
    if (map == null || !_gate.isOpen) {
      return; // stashed; replayed by [onStyleLoaded]
    }
    try {
      final PolylineAnnotationManager manager = _lineManager ??= await map
          .annotations
          .createPolylineAnnotationManager();
      await manager.deleteAll();
      for (final RouteLine line in _routeLines) {
        if (!line.isDrawable) {
          continue;
        }
        final int color = line.color ?? _defaultLineColor;
        // Mapbox's polyline annotations have no dash pattern, so a dashed line
        // is drawn as a run of short segments along the same path.
        final List<List<LatLon>> pieces = line.dashed
            ? dashPolyline(line.points)
            : <List<LatLon>>[line.points];
        for (final List<LatLon> piece in pieces) {
          if (piece.length < 2) {
            continue;
          }
          await manager.create(
            PolylineAnnotationOptions(
              geometry: LineString(
                coordinates: <Position>[
                  for (final LatLon point in piece)
                    Position(point.longitude, point.latitude),
                ],
              ),
              lineColor: color,
              lineWidth: line.width,
            ),
          );
        }
      }
    } catch (_) {
      // Map disposed mid-flight.
    }
  }

  /// Wired to `MapWidget.onCameraChangeListener`.
  void onCameraChanged(CameraChangedEventData event) {
    final CameraState state = event.cameraState;
    final Position center = state.center.coordinates;
    final LatLon? target = LatLon.tryParse(center.lat, center.lng);
    if (target == null) {
      return;
    }
    _camera = Camera(
      target: target,
      zoom: state.zoom,
      bearing: state.bearing,
      tilt: state.pitch,
    );
    _emitCamera(_camera);
  }

  Future<void> _apply(Camera camera, {bool animated = false}) async {
    final MapboxMap? map = _map;
    if (map == null) {
      return;
    }
    final CameraOptions options = CameraOptions(
      center: Point(
        coordinates: Position(camera.target.longitude, camera.target.latitude),
      ),
      zoom: camera.zoom,
      bearing: camera.bearing,
      pitch: camera.tilt,
    );
    if (animated) {
      await _guard(
        () => map.easeTo(options, MapAnimationOptions(duration: 600)),
      );
    } else {
      await _guard(() => map.setCamera(options));
    }
  }

  /// Runs a map platform call, swallowing "channel-error"/disposed errors.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Map not ready or disposed; nothing we can do.
    }
  }

  void _emitCamera(Camera camera) {
    // moveCamera emits, then the native camera listener emits again for the same
    // move; without this the stream (and every provider watching it) churns on
    // duplicate frames. Only emit when the camera meaningfully changed.
    final Camera? last = _lastEmitted;
    if (last != null && _sameCamera(last, camera)) {
      return;
    }
    _lastEmitted = camera;
    if (!_cameraController.isClosed) {
      _cameraController.add(camera);
    }
  }

  bool _sameCamera(Camera a, Camera b) =>
      (a.target.latitude - b.target.latitude).abs() < 1e-6 &&
      (a.target.longitude - b.target.longitude).abs() < 1e-6 &&
      (a.zoom - b.zoom).abs() < 0.01 &&
      (a.bearing - b.bearing).abs() < 0.1 &&
      (a.tilt - b.tilt).abs() < 0.1;

  void _emitTap(LatLon position) {
    if (!_tapController.isClosed) {
      _tapController.add(position);
    }
  }

  void _emitLongPress(LatLon position) {
    if (!_longPressController.isClosed) {
      _longPressController.add(position);
    }
  }

  /// A result marker was tapped: report the place id (matched by position, as
  /// the annotations carry SDK-generated ids).
  void _onMarkerTap(PointAnnotation annotation) {
    _lastMarkerTapAt = DateTime.now();
    final Position coordinates = annotation.geometry.coordinates;
    final LatLon? tapped = LatLon.tryParse(coordinates.lat, coordinates.lng);
    if (tapped == null) {
      return;
    }
    for (final Marker marker in _markers) {
      if (marker.position.distanceTo(tapped) < 40) {
        if (!_markerTapController.isClosed) {
          _markerTapController.add(marker.id);
        }
        return;
      }
    }
  }

  /// A friend badge was tapped: report the friend's public key (matched by
  /// position, as the annotations carry SDK-generated ids).
  void _onFriendTap(PointAnnotation annotation) {
    final Position coordinates = annotation.geometry.coordinates;
    final LatLon? tapped = LatLon.tryParse(coordinates.lat, coordinates.lng);
    if (tapped == null) {
      return;
    }
    for (final FriendMarker marker in _friendMarkers) {
      if (marker.position.distanceTo(tapped) < 40) {
        if (!_friendMarkerTapController.isClosed) {
          _friendMarkerTapController.add(marker.pubkey);
        }
        return;
      }
    }
  }

  /// A review badge was tapped: report the place key (matched by position, as
  /// the annotations carry SDK-generated ids).
  void _onReviewTap(PointAnnotation annotation) {
    final Position coordinates = annotation.geometry.coordinates;
    final LatLon? tapped = LatLon.tryParse(coordinates.lat, coordinates.lng);
    if (tapped == null) {
      return;
    }
    for (final ReviewMarker marker in _reviewMarkers) {
      if (marker.position.distanceTo(tapped) < 60) {
        if (!_reviewMarkerTapController.isClosed) {
          _reviewMarkerTapController.add(marker.placeKey);
        }
        return;
      }
    }
  }

  /// Handles a tap on a Standard-style POI featureset (restaurant/shop icons
  /// drawn by the basemap) and opens its details.
  void _onPoiFeatureTap(
    TypedFeaturesetFeature<StandardPOIs> feature,
    MapContentGestureContext context,
  ) {
    final Place? place = _placeFromPoiFeature(feature, context);
    if (place != null) {
      _emitPoi(place);
    }
  }

  /// Falls back to a rendered-feature query for non-Standard styles (the v12
  /// stock styles keep their POIs in symbol layers).
  Future<void> _emitPoiAt(LatLon target) async {
    if (_recentMarkerTap()) {
      return; // a drawn marker handled this tap
    }
    final Place? place = await _queryPoi(target);
    if (place != null) {
      _emitPoi(place);
    }
  }

  /// Publishes a tapped POI, de-duplicating the two tap sources (featureset and
  /// rendered-feature query) and ignoring taps already handled by a marker.
  void _emitPoi(Place place) {
    if (_recentMarkerTap()) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? last = _lastPoiEmitAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 120)) {
      return;
    }
    _lastPoiEmitAt = now;
    if (!_poiTapController.isClosed) {
      _poiTapController.add(place);
    }
  }

  bool _recentMarkerTap() {
    final DateTime? last = _lastMarkerTapAt;
    return last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 500);
  }

  /// Builds a [Place] from a Standard-style POI feature, falling back to the
  /// gesture coordinate when the feature geometry is unavailable.
  Place? _placeFromPoiFeature(
    TypedFeaturesetFeature<StandardPOIs> feature,
    MapContentGestureContext context,
  ) {
    final Object? name = feature.properties['name'];
    if (name is! String || name.isEmpty) {
      return null;
    }
    final Position touch = context.point.coordinates;
    final LatLon? position =
        _pointFromGeometry(feature.geometry) ??
        LatLon.tryParse(touch.lat, touch.lng);
    if (position == null) {
      return null;
    }
    final Object? category =
        feature.properties['maki'] ?? feature.properties['class'];
    final String? featureId = feature.id?.id;
    return Place(
      id: _placeIdFor(featureId, name: name, position: position),
      name: name,
      position: position,
      category: _displayCategory(category),
    );
  }

  /// A stable id for a map feature: the real OSM reference when the feature id
  /// encodes one (`node/2764050762`), else the raw id, else a synthetic
  /// `map:name@lat,lon` so a place is never id-less.
  String _placeIdFor(
    Object? rawId, {
    required String name,
    required LatLon position,
  }) {
    final String? osmRef = OsmRef.fromEncodedFeatureId(rawId);
    if (osmRef != null) {
      return osmRef;
    }
    if (rawId is String && rawId.trim().isNotEmpty) {
      return rawId.trim();
    }
    if (rawId is int) {
      return '$rawId';
    }
    return 'map:$name@${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)}';
  }

  /// Turns a raw POI tag (`fast-food`, `food_and_drink`) into a label safe to
  /// show the user.
  String? _displayCategory(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  /// Reads a point coordinate from a GeoJSON geometry map, tolerating both a
  /// coordinate list and a nested coordinate object.
  LatLon? _pointFromGeometry(Map<String?, Object?> geometry) {
    Object? coordinates = geometry['coordinates'];
    if (coordinates is Map) {
      coordinates = coordinates['coordinates'];
    }
    if (coordinates is! List || coordinates.length < 2) {
      return null;
    }
    return LatLon.tryParse(coordinates[1], coordinates[0]);
  }

  Future<Place?> _queryPoi(LatLon target) async {
    final MapboxMap? map = _map;
    if (map == null) {
      return null;
    }
    try {
      final ScreenCoordinate pixel = await map.pixelForCoordinate(
        Point(coordinates: Position(target.longitude, target.latitude)),
      );
      const double pad = 16;
      final List<QueriedRenderedFeature?> features = await map
          .queryRenderedFeatures(
            RenderedQueryGeometry.fromScreenBox(
              ScreenBox(
                min: ScreenCoordinate(x: pixel.x - pad, y: pixel.y - pad),
                max: ScreenCoordinate(x: pixel.x + pad, y: pixel.y + pad),
              ),
            ),
            RenderedQueryOptions(),
          );
      Place? fallback;
      for (final QueriedRenderedFeature? feature in features) {
        final QueriedFeature? queried = feature?.queriedFeature;
        if (queried == null) {
          continue;
        }
        final Place? place = _placeFromFeature(queried.feature);
        if (place == null) {
          continue;
        }
        final bool poiLayer = feature!.layers.any(
          (String? layer) => layer != null && layer.contains('poi'),
        );
        if (poiLayer) {
          return place;
        }
        fallback ??= place;
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  /// Parses a rendered GeoJSON feature into a [Place] when it is a named point
  /// (POIs are points; roads/areas are lines/polygons and are ignored).
  ///
  /// The decoded maps are typed loosely (`Map`), so keys are read dynamically.
  Place? _placeFromFeature(Map<String?, Object?> feature) {
    final Object? geometry = feature['geometry'];
    if (geometry is! Map) {
      return null;
    }
    if (geometry['type'] != 'Point') {
      return null;
    }
    final Object? coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      return null;
    }
    final LatLon? position = LatLon.tryParse(coordinates[1], coordinates[0]);
    if (position == null) {
      return null;
    }
    final Object? properties = feature['properties'];
    if (properties is! Map) {
      return null;
    }
    final Object? name = properties['name'] ?? properties['name_en'];
    if (name is! String || name.isEmpty) {
      return null;
    }
    final Object? id = feature['id'];
    final Object? category =
        properties['class'] ?? properties['maki'] ?? properties['category'];
    return Place(
      id: _placeIdFor(id, name: name, position: position),
      name: name,
      position: position,
      category: category is String ? category : null,
    );
  }

  /// Releases resources; wired to `ref.onDispose` at the composition root.
  void dispose() {
    detach();
    _friendMarkerComposer.dispose();
    _reviewMarkerComposer.dispose();
    _transitStopComposer.dispose();
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
