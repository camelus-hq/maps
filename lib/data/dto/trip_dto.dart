import 'dart:convert';

import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/entities/trip.dart';

/// Lenient JSON codec for persisting recorded trips in the local database.
///
/// Hostile input is dropped rather than thrown: a malformed entry, a bad
/// timestamp or a track point outside the valid coordinate range reads back as
/// nothing or is skipped. The track is capped, so a corrupt or hand-edited store
/// can never make the app allocate unbounded memory (AGENTS.md §Never crash).
abstract final class TripDto {
  /// Cap on stored track points (the recorder keeps at most a few thousand).
  static const int maxTrackPoints = 5000;

  /// Cap on a stored name's length.
  static const int maxNameLength = 120;

  static Map<String, Object?> toJson(Trip trip) => <String, Object?>{
    'id': trip.id,
    'startedAt': trip.startedAt.toUtc().millisecondsSinceEpoch,
    'endedAt': trip.endedAt.toUtc().millisecondsSinceEpoch,
    'mode': trip.mode.name,
    'distanceMeters': trip.distanceMeters,
    if (trip.originName != null) 'origin': trip.originName,
    if (trip.destinationName != null) 'destination': trip.destinationName,
    'track': <List<double>>[
      for (final LatLon point in trip.track)
        <double>[point.latitude, point.longitude],
    ],
  };

  /// Decodes one stored trip, or `null` when it is malformed.
  static Trip? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? id = raw['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    final DateTime? startedAt = _time(raw['startedAt']);
    if (startedAt == null) {
      return null;
    }
    final DateTime? endedRaw = _time(raw['endedAt']);
    final DateTime endedAt = endedRaw == null || endedRaw.isBefore(startedAt)
        ? startedAt
        : endedRaw;
    final TravelMode? mode = _mode(raw['mode']);
    if (mode == null) {
      return null;
    }
    final double distance = _finite(raw['distanceMeters']) ?? 0;
    return Trip(
      id: id.length > 80 ? id.substring(0, 80) : id,
      startedAt: startedAt,
      endedAt: endedAt,
      mode: mode,
      distanceMeters: distance < 0 ? 0 : distance,
      originName: _name(raw['origin']),
      destinationName: _name(raw['destination']),
      track: _track(raw['track']),
    );
  }

  static String encodeList(List<Trip> trips) =>
      jsonEncode(trips.map(toJson).toList(growable: false));

  static List<Trip> decodeList(String? json) {
    if (json == null || json.isEmpty) {
      return const <Trip>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const <Trip>[];
    }
    if (decoded is! List<Object?>) {
      return const <Trip>[];
    }
    final List<Trip> trips = <Trip>[];
    for (final Object? item in decoded) {
      final Trip? trip = fromJson(item);
      if (trip != null) {
        trips.add(trip);
      }
    }
    return trips;
  }

  static List<LatLon> _track(Object? raw) {
    if (raw is! List<Object?>) {
      return const <LatLon>[];
    }
    final List<LatLon> points = <LatLon>[];
    for (final Object? item in raw) {
      if (points.length >= maxTrackPoints) {
        break;
      }
      if (item is! List<Object?> || item.length < 2) {
        continue;
      }
      final LatLon? point = LatLon.tryParse(item[0], item[1]);
      if (point != null) {
        points.add(point);
      }
    }
    return points;
  }

  static DateTime? _time(Object? raw) {
    final int? millis = switch (raw) {
      final int value => value,
      final double value => value.isFinite ? value.toInt() : null,
      _ => null,
    };
    if (millis == null) {
      return null;
    }
    try {
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } on ArgumentError {
      return null;
    }
  }

  static TravelMode? _mode(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final TravelMode mode in TravelMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return null;
  }

  static String? _name(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.length > maxNameLength
        ? trimmed.substring(0, maxNameLength)
        : trimmed;
  }

  static double? _finite(Object? raw) => switch (raw) {
    final double value when value.isFinite => value,
    final int value => value.toDouble(),
    _ => null,
  };
}
