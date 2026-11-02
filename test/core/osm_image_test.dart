import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/osm_image.dart';

/// The OSM `image` reader: it must only ever hand the UI an `http(s)` URL, and
/// rewrite Wikimedia Commons page links to the actual image.
void main() {
  test('keeps a direct image URL', () {
    expect(
      OsmImage.direct('https://example.org/photo.jpg'),
      'https://example.org/photo.jpg',
    );
  });

  test('rewrites a Commons File page to Special:FilePath', () {
    expect(
      OsmImage.direct(
        'https://commons.wikimedia.org/wiki/File:Potsdam_brandenburger_tor.jpg',
      ),
      'https://commons.wikimedia.org/wiki/Special:FilePath/'
      'Potsdam_brandenburger_tor.jpg',
    );
  });

  test('expands the short File: form', () {
    expect(
      OsmImage.direct('File:Some photo.jpg'),
      'https://commons.wikimedia.org/wiki/Special:FilePath/Some%20photo.jpg',
    );
  });

  test('rejects non-http values and empty input', () {
    expect(OsmImage.direct('ftp://example.org/a.png'), isNull);
    expect(OsmImage.direct('example.org/a.png'), isNull);
    expect(OsmImage.direct('   '), isNull);
    expect(OsmImage.direct(null), isNull);
    expect(OsmImage.direct('https://${'a' * 3000}'), isNull);
  });

  test('collects the main and numbered images, sorted and de-duplicated', () {
    final List<String> urls = OsmImage.urls(<String, String>{
      'image:2': 'https://example.org/b.jpg',
      'image': 'https://example.org/a.jpg',
      'image:0': 'https://example.org/a.jpg',
      'image:1': 'https://example.org/c.jpg',
      'name': 'Not an image',
    });
    expect(urls, <String>[
      'https://example.org/a.jpg',
      'https://example.org/c.jpg',
      'https://example.org/b.jpg',
    ]);
  });

  test('bounds the number of images', () {
    final Map<String, String> tags = <String, String>{
      for (int i = 0; i < 20; i++) 'image:$i': 'https://example.org/$i.jpg',
    };
    expect(OsmImage.urls(tags), hasLength(OsmImage.maxImages));
  });
}
