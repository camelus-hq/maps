/// Supported travel modes.
///
/// `transit` is planned through [TransitRoutingService] (the Transitous/MOTIS
/// adapter) rather than the turn-by-turn [RoutingService], because a
/// public-transport journey is a sequence of legs with transfers, not a single
/// street route.
enum TravelMode {
  drive,
  walk,
  cycle,
  transit;

  /// Whether this mode is planned as a public-transport journey.
  bool get isTransit => this == TravelMode.transit;
}
