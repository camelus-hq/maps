import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/osm_ref.dart';

/// Mapbox vector-tile feature ids encode OSM ids as `id * 10 + type`
/// (node 0, way 1, relation 4). Writing the encoded value into a review's `d`
/// tag produced `openstreetmap:27640507620` for OSM node `2764050762`, so this
/// decode is the fix for the place key.
void main() {
  group('fromEncodedFeatureId', () {
    test('decodes a node (id * 10)', () {
      expect(OsmRef.fromEncodedFeatureId('27640507620'), 'node/2764050762');
      expect(OsmRef.fromEncodedFeatureId(27640507620), 'node/2764050762');
      expect(OsmRef.fromEncodedFeatureId('1230'), 'node/123');
    });

    test('decodes a way (id * 10 + 1)', () {
      expect(OsmRef.fromEncodedFeatureId('1231'), 'way/123');
    });

    test('decodes a relation (id * 10 + 4)', () {
      expect(OsmRef.fromEncodedFeatureId('1234'), 'relation/123');
    });

    test('refuses values that are not OSM ids', () {
      // Mapbox uses 0 for a feature whose OSM id was dropped when merging.
      expect(OsmRef.fromEncodedFeatureId('0'), isNull);
      expect(OsmRef.fromEncodedFeatureId(0), isNull);
      // Unknown type digit.
      expect(OsmRef.fromEncodedFeatureId('1232'), isNull);
      expect(OsmRef.fromEncodedFeatureId('1233'), isNull);
      // Too small to hold an id.
      expect(OsmRef.fromEncodedFeatureId('9'), isNull);
      // Not numeric at all.
      expect(OsmRef.fromEncodedFeatureId('poi.123'), isNull);
      expect(OsmRef.fromEncodedFeatureId('node/2764050762'), isNull);
      expect(OsmRef.fromEncodedFeatureId(null), isNull);
      expect(OsmRef.fromEncodedFeatureId(double.nan), isNull);
      expect(OsmRef.fromEncodedFeatureId('-1230'), isNull);
    });
  });

  group('fromTypeAndId', () {
    test('builds the reference form', () {
      expect(OsmRef.fromTypeAndId('node', 2764050762), 'node/2764050762');
      expect(OsmRef.fromTypeAndId('Way', 5), 'way/5');
      expect(OsmRef.fromTypeAndId('relation', 7), 'relation/7');
      expect(OsmRef.fromTypeAndId('building', 7), isNull);
      expect(OsmRef.fromTypeAndId('node', 0), isNull);
    });
  });

  group('isRef', () {
    test('recognises OSM references', () {
      expect(OsmRef.isRef('node/1'), isTrue);
      expect(OsmRef.isRef('way/123'), isTrue);
      expect(OsmRef.isRef('relation/123'), isTrue);
      expect(OsmRef.isRef('node/abc'), isFalse);
      expect(OsmRef.isRef('poi.1'), isFalse);
      expect(OsmRef.isRef('node/'), isFalse);
      expect(OsmRef.isRef('/1'), isFalse);
      expect(OsmRef.isRef('1230'), isFalse);
    });
  });
}
