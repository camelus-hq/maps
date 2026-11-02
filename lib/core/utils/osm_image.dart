/// Normalises an OpenStreetMap `image` tag into a direct, safe image URL.
///
/// The `image` tag is a free-form OSM value and can be a direct file URL, a
/// Wikimedia Commons `File:` page, or the short `File:Name.jpg` form. Only
/// `http(s)` results are returned; anything else is treated as unusable rather
/// than crashing the Photos tab. Commons *page* links are rewritten to the
/// `Special:FilePath` redirect so they resolve to the actual image bytes.
///
/// Pure Dart (the widget layer owns the actual network load).
abstract final class OsmImage {
  /// How many `image` values to keep (the main tag plus `image:0`…`image:5`).
  static const int maxImages = 6;

  /// The direct image URLs found in [tags], de-duplicated, bounded and in tag
  /// order. Empty when the place has no usable `image` tag.
  static List<String> urls(Map<String, String> tags) {
    final List<String> ordered = <String>[];
    // The unnumbered key first, then the numbered variants in numeric order.
    final String? main = tags['image'];
    if (main != null) {
      ordered.add(main);
    }
    final List<MapEntry<int, String>> numbered = <MapEntry<int, String>>[];
    for (final MapEntry<String, String> entry in tags.entries) {
      final String? index = _numberedIndex(entry.key);
      if (index != null) {
        numbered.add(
          MapEntry<int, String>(int.tryParse(index) ?? 0, entry.value),
        );
      }
    }
    numbered.sort(
      (MapEntry<int, String> a, MapEntry<int, String> b) =>
          a.key.compareTo(b.key),
    );
    for (final MapEntry<int, String> entry in numbered) {
      ordered.add(entry.value);
    }

    final List<String> urls = <String>[];
    for (final String raw in ordered) {
      final String? url = direct(raw);
      if (url != null && !urls.contains(url)) {
        urls.add(url);
      }
      if (urls.length >= maxImages) {
        break;
      }
    }
    return urls;
  }

  /// A single usable direct URL for [raw], or `null`.
  static String? direct(String? raw) {
    if (raw == null) {
      return null;
    }
    final String value = raw.trim();
    if (value.isEmpty || value.length > 2048) {
      return null;
    }
    final String lower = value.toLowerCase();
    if (lower.startsWith('file:')) {
      return _commonsFilePath(value.substring('file:'.length));
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    // A Wikimedia Commons `File:` page is not the image itself.
    final String host = uri.host.toLowerCase();
    if ((host == 'commons.wikimedia.org' || host.endsWith('.wikimedia.org')) &&
        uri.path.startsWith('/wiki/File:')) {
      return _commonsFilePath(uri.path.substring('/wiki/File:'.length));
    }
    return uri.toString();
  }

  /// The numeric index in an `image:<n>` key, or `null` for any other key.
  static String? _numberedIndex(String key) {
    if (!key.startsWith('image:')) {
      return null;
    }
    final String suffix = key.substring('image:'.length);
    if (suffix.isEmpty || int.tryParse(suffix) == null) {
      return null;
    }
    return suffix;
  }

  /// `Special:FilePath/<name>` for a Commons file name (the redirect resolves to
  /// the image bytes and tolerates spaces).
  static String? _commonsFilePath(String name) {
    String value = name;
    try {
      value = Uri.decodeComponent(value);
    } on FormatException {
      // Keep the raw value; `Uri.encodeComponent` below still makes it safe.
    }
    value = value.trim();
    if (value.isEmpty || value.length > 512 || value.contains('\n')) {
      return null;
    }
    return 'https://commons.wikimedia.org/wiki/Special:FilePath/'
        '${Uri.encodeComponent(value)}';
  }
}
