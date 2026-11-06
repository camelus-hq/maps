import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/ports/routing_service.dart';
import '../dto/valhalla_route_dto.dart';

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
    return List<Route>.unmodifiable(routes);
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
