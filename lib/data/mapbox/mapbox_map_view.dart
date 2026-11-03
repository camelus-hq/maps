import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'mapbox_map_service.dart';

/// The raw Mapbox map widget.
///
/// This is the single place where Mapbox *view* types are used outside
/// `lib/data/mapbox/`'s service, which `plan/architecture.md` §4 allows for the
/// unavoidable platform view. All data crosses as domain types.
///
/// It detaches from the service on disposal so map calls made while the widget
/// is off-screen (e.g. search results) don't hit a dead platform channel.
class MapboxMapView extends StatefulWidget {
  const MapboxMapView({super.key, required this.service});

  final MapboxMapService service;

  @override
  State<MapboxMapView> createState() => _MapboxMapViewState();
}

class _MapboxMapViewState extends State<MapboxMapView> {
  bool? _lastDarkMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;
    if (_lastDarkMode == darkMode) {
      return;
    }
    _lastDarkMode = darkMode;
    unawaited(widget.service.setDarkMode(darkMode));
  }

  @override
  void dispose() {
    widget.service.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: widget.service.styleUri,
      onMapCreated: widget.service.attach,
      // Annotation managers and style layers may only be touched once the style
      // is ready; the service stashes content until this fires (see
      // MapboxMapService.onStyleLoaded).
      onStyleLoadedListener: (_) => widget.service.onStyleLoaded(),
      onCameraChangeListener: widget.service.onCameraChanged,
    );
  }
}
