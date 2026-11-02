import '../../domain/entities/place.dart';
import '../../domain/ports/osm_place_source.dart';

/// In-memory [OsmPlaceSource] for tests and keyless runs.
///
/// Nothing is looked up on the network: a reference resolves only when a test
/// (or the demo) seeded it, so the keyless app keeps falling back to the raw
/// reference it already has.
class FakeOsmPlaceSource implements OsmPlaceSource {
  FakeOsmPlaceSource({Map<String, Place>? places})
    : _places = <String, Place>{...?places};

  final Map<String, Place> _places;

  /// Every reference this fake was asked about, in order.
  final List<String> lookups = <String>[];

  /// Registers a place for a reference such as `node/2764050762`.
  void seed(String osmRef, Place place) {
    _places[osmRef.trim()] = place;
  }

  @override
  Future<Place?> lookup(String osmRef) async {
    final String ref = osmRef.trim();
    lookups.add(ref);
    return _places[ref];
  }
}
