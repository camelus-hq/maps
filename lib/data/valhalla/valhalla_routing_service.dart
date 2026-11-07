import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/cycling_options.dart';
import '../../domain/entities/elevation.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/ports/routing_service.dart';
import '../dto/valhalla_route_dto.dart';
import 'polyline_codec.dart';
import 'valhalla_height_mapper.dart';

/// [RoutingService] backed by a Valhalla HTTP endpoint.
class ValhallaRoutingService implements RoutingService {
  ValhallaRoutingService({required this.client, required this.baseUrl});

  final http.Client client;
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 12);
  static const int _alternates = 2;

  @override
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
    CyclingOptions? cycling,
  }) async {
    if (waypoints.length < 2) {
      throw const ValidationException('A route needs at least two waypoints');
    }
    final Uri uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/route',
    );
    final Map<String, Object?> body = <String, Object?>{
      'locations': <Map<String, Object?>>[
        for (final LatLon point in waypoints)
          <String, Object?>{'lat': point.latitude, 'lon': point.longitude},
      ],
      'costing': _costing(mode),
      'directions_options': <String, Object?>{'units': 'kilometers'},
      // Ask Valhalla for lane-level guidance (`maneuver.lanes`).
      'turn_lanes': true,
      'alternates': _alternates,
    };
    // Bicycle cost tuning (bicycle_type, hills/surface/road weighting, speed).
    // Only options that differ from Valhalla's defaults are sent, so an
    // untouched panel never changes the route. Never sent for drive/walk.
    if (mode == TravelMode.cycle && cycling != null) {
      final Map<String, Object?> overrides = cycling.changedOptions();
      if (overrides.isNotEmpty) {
        body['costing_options'] = <String, Object?>{'bicycle': overrides};
      }
    }

    final http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const RequestTimeoutException('Routing request timed out');
    } on http.ClientException catch (error) {
      // No connection / DNS failure / connection dropped: treat as offline.
      throw OfflineException('Routing request failed', cause: error);
    } catch (error) {
      throw NetworkException('Routing request failed', cause: error);
    }

    if (response.statusCode != 200) {
      throw NetworkException('Routing failed (HTTP ${response.statusCode})');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ValidationException('Malformed routing response');
    }
    final List<Route> routes = ValhallaRouteDto.routesFromResponse(decoded);
    if (routes.isEmpty) {
      throw const NotFoundException('No route found');
    }
    // Gradient/ascent guidance is a cycling-only concern, so only fetch the
    // elevation profile for bike routes (and never let it fail the route).
    if (mode == TravelMode.cycle) {
      final List<Route> withElevation = await Future.wait(
        routes.map(_withElevation),
      );
      return List<Route>.unmodifiable(withElevation);
    }
    return List<Route>.unmodifiable(routes);
  }

  /// Attaches the elevation profile from Valhalla's `/height` service to
  /// [route]. Any failure (no elevation dataset, timeout, malformed body)
  /// leaves the route without a profile — the gradient page is simply omitted.
  Future<Route> _withElevation(Route route) async {
    if (route.geometry.length < 2) {
      return route;
    }
    final Uri uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/height',
    );
    final Map<String, Object?> body = <String, Object?>{
      'encoded_polyline': encodePolyline(route.geometry),
      'range': true,
      'resample_distance': 25,
    };
    try {
      final http.Response response = await client
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return route;
      }
      final Object? decoded = jsonDecode(response.body);
      final ElevationProfile profile = ValhallaHeightMapper.fromResponse(
        decoded,
      );
      return profile.isEmpty ? route : route.copyWith(elevation: profile);
    } catch (_) {
      return route;
    }
  }

  String _costing(TravelMode mode) => switch (mode) {
    TravelMode.drive => 'auto',
    TravelMode.walk => 'pedestrian',
    TravelMode.cycle => 'bicycle',
    // Transit journeys are planned by the TransitRoutingService adapter, never
    // here; refuse rather than silently route by car.
    TravelMode.transit => throw const UnsupportedException(
      'Transit is not handled by the Valhalla adapter',
    ),
  };
}
