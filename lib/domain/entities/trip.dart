import 'lat_lon.dart';
import 'travel_mode.dart';

/// A recorded trip: the path actually travelled during a guidance session,
/// captured locally so it can be reviewed and exported as GPX.
///
/// Immutable. The recorded breadcrumb [track] is bounded by the recorder (see
/// `NavigationController`) and again by the persistence codec, since the local
/// database is an untrusted store.
class Trip {
  const Trip({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.mode,
    required this.distanceMeters,
    required this.track,
    this.originName,
    this.destinationName,
  });

  /// A stable id (the trip's start instant, in microseconds).
  final String id;

  /// When the trip began (wall clock).
  final DateTime startedAt;

  /// When it ended — on arrival, or when the user stopped guidance.
  final DateTime endedAt;

  final TravelMode mode;

  /// Distance actually covered, in metres. It comes from the guidance session,
  /// so it survives a mid-trip reroute.
  final double distanceMeters;

  /// The breadcrumb path actually travelled, oldest point first.
  final List<LatLon> track;

  /// The planned origin label, when known.
  final String? originName;

  /// The planned destination label, when known.
  final String? destinationName;

  /// How long the trip took (never negative).
  Duration get duration {
    final Duration value = endedAt.difference(startedAt);
    return value.isNegative ? Duration.zero : value;
  }

  /// The first recorded point, or `null` for an empty track.
  LatLon? get start => track.isEmpty ? null : track.first;

  /// The last recorded point, or `null` for an empty track.
  LatLon? get end => track.isEmpty ? null : track.last;

  /// A human title: the destination when known, else a generic label.
  String get title {
    final String? destination = destinationName?.trim();
    if (destination != null && destination.isNotEmpty) {
      return destination;
    }
    return 'Recorded trip';
  }
}
