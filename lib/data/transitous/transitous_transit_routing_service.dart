import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/transit.dart';
import '../../domain/ports/transit_routing_service.dart';
import '../dto/motis_plan_dto.dart';

/// [TransitRoutingService] backed by the Transitous (MOTIS 2) HTTP API.
///
/// Transitous is a free, community-run, non-commercial service; its usage
/// policy asks for a descriptive `User-Agent` with contact information and for
/// resource use to stay light. Every request here is a single `/plan` call per
/// segment, results are never polled, and the response is bounded while parsing.
///
/// Multi-stop journeys: MOTIS's `via` parameter only accepts stop ids, and our
/// waypoints are bare coordinates, so a journey with intermediate stops is
/// planned segment by segment and chained — each segment departs when the
/// previous one arrives — producing one combined itinerary. Two-point journeys
/// return the provider's own alternatives.
class TransitousTransitRoutingService implements TransitRoutingService {
  TransitousTransitRoutingService({
    required this.client,
    this.baseUrl = defaultBaseUrl,
    this.userAgent = defaultUserAgent,
    this.timeout = const Duration(seconds: 15),
  });

  static const String defaultBaseUrl = 'https://api.transitous.org/api';

  /// Transitous asks every caller to identify itself with a contact.
  static const String defaultUserAgent = 'OpenMaps/0.1 (Flutter)';

  final http.Client client;
  final String baseUrl;
  final String userAgent;
  final Duration timeout;

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async {
    final List<LatLon> waypoints = query.waypoints;
    if (waypoints.length < 2) {
      throw const ValidationException('A journey needs at least two waypoints');
    }
    if (waypoints.length == 2) {
      return _planSegment(
        from: waypoints[0],
        to: waypoints[1],
        query: query,
        time: query.time,
      );
    }
    return _planChainedStops(waypoints, query);
  }

  /// Plans a multi-stop journey by chaining segments; each next segment departs
  /// when the previous one arrives.
  Future<List<TransitItinerary>> _planChainedStops(
    List<LatLon> waypoints,
    TransitQuery query,
  ) async {
    final List<TransitLeg> legs = <TransitLeg>[];
    DateTime? time = query.time;
    DateTime? start;
    DateTime? end;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final List<TransitItinerary> segment = await _planSegment(
        from: waypoints[i],
        to: waypoints[i + 1],
        query: query,
        time: time,
      );
      final TransitItinerary first = segment.first;
      start ??= first.startTime;
      end = first.endTime;
      legs.addAll(first.legs);
      time = first.endTime;
    }
    if (legs.isEmpty || start == null || end == null) {
      return const <TransitItinerary>[];
    }
    return List<TransitItinerary>.unmodifiable(<TransitItinerary>[
      TransitItinerary(
        legs: List<TransitLeg>.unmodifiable(legs),
        startTime: start,
        endTime: end,
      ),
    ]);
  }

  Future<List<TransitItinerary>> _planSegment({
    required LatLon from,
    required LatLon to,
    required TransitQuery query,
    required DateTime? time,
  }) async {
    final Uri uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1/plan',
    ).replace(queryParameters: _queryParameters(from, to, query, time));

    final http.Response response;
    try {
      response = await client
          .get(
            uri,
            headers: <String, String>{
              'User-Agent': userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RequestTimeoutException('Transit planning timed out');
    } on http.ClientException catch (error) {
      // No connection / DNS failure / connection dropped: treat as offline.
      throw OfflineException('Transit planning failed', cause: error);
    } catch (error) {
      throw NetworkException('Transit planning failed', cause: error);
    }

    if (response.statusCode != 200) {
      throw NetworkException(
        'Transit planning failed (HTTP ${response.statusCode})',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ValidationException('Malformed transit response');
    }
    final List<TransitItinerary> itineraries =
        MotisPlanDto.itinerariesFromResponse(decoded);
    if (itineraries.isEmpty) {
      throw const NotFoundException('No journeys found');
    }
    return itineraries;
  }

  Map<String, String> _queryParameters(
    LatLon from,
    LatLon to,
    TransitQuery query,
    DateTime? time,
  ) {
    return <String, String>{
      'fromPlace': _place(from),
      'toPlace': _place(to),
      if (time != null) 'time': _formatTime(time),
      'arriveBy': query.arriveBy ? 'true' : 'false',
      'numItineraries': query.numItineraries.clamp(1, 20).toString(),
      if (query.preferredModes.isNotEmpty)
        'transitModes': <String>[
          for (final TransitMode mode in query.preferredModes) mode.motisName,
        ].join(','),
      if (query.maxTransfers != null)
        'maxTransfers': query.maxTransfers!.clamp(0, 10).toString(),
    };
  }

  static String _place(LatLon point) =>
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

  /// MOTIS wants a plain UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`).
  static String _formatTime(DateTime time) {
    final DateTime utc = time.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}Z';
  }
}
