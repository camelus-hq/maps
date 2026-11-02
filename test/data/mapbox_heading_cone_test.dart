import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/marker_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildOriginalHeadingConeImage returns a non-empty PNG', () async {
    final Uint8List bytes = await buildOriginalHeadingConeImage(
      argb: 0xFF116B5B,
    );
    expect(bytes, isNotEmpty);
    // PNG magic number.
    expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });
}
