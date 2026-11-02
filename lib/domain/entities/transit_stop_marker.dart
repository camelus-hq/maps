import 'lat_lon.dart';

/// How a transit stop is drawn on the map.
enum TransitStopEmphasis {
  /// A stop the vehicle passes through without a change (a small circle).
  pass,

  /// A stop where the traveller boards or leaves a vehicle (a larger circle).
  board,
}

/// A stop drawn on the map for a public-transport journey: a circle with a white
/// centre and a ring in the line's colour, larger where the traveller enters or
/// leaves a vehicle.
class TransitStopMarker {
  const TransitStopMarker({
    required this.id,
    required this.position,
    this.emphasis = TransitStopEmphasis.pass,
    this.color,
  });

  /// Stable id (the coordinate, so a transfer stop is drawn once).
  final String id;
  final LatLon position;
  final TransitStopEmphasis emphasis;

  /// Ring colour (the line's colour); `null` lets the map pick its default.
  final int? color;

  bool get isBoard => emphasis == TransitStopEmphasis.board;
}
