import 'package:flutter/widgets.dart';

import '../../common/shimmer.dart';
import '../../design/play.dart';

/// The Photos tab: the place's OpenStreetMap `image` (and `image:<n>`) pictures,
/// loaded at runtime. Our own media corpus stays empty (AGENTS.md §Assets), so
/// these are the only photos on offer — an honest empty state when OSM has none.
class PlacePhotos extends StatelessWidget {
  const PlacePhotos({super.key, required this.urls});

  /// Direct `http(s)` image URLs, already normalised and bounded by `OsmImage`.
  final List<String> urls;

  /// Wikimedia asks every caller to identify itself; sending that for every host
  /// is harmless and keeps the request welcome.
  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'OpenMaps/0.1 (Flutter; OpenStreetMap place photo)',
  };

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    if (urls.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PlaySurface(
            tone: PlayTone.sunken,
            radius: PlayRadii.md,
            shadow: PlayShadow.none,
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No photos yet',
                  style: PlayType.caption.copyWith(color: colors.inkMuted),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String url in urls) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(PlayRadii.md),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                url,
                headers: _headers,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stack,
                ) => _Broken(url: url),
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? progress,
                    ) => progress == null
                    ? child
                    : const Shimmer(child: ShimmerBox()),
              ),
            ),
          ),
          const SizedBox(height: PlaySpace.sm),
          Text(
            'Photo from OpenStreetMap',
            style: PlayType.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: PlaySpace.md),
        ],
      ],
    );
  }
}

/// The fallback when a photo cannot be loaded (offline, hostile URL, 404).
class _Broken extends StatelessWidget {
  const _Broken({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return ColoredBox(
      color: colors.surfaceSunken,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.brokenImage, color: colors.inkMuted),
            const SizedBox(height: PlaySpace.xs),
            Text(
              'Photo unavailable',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
