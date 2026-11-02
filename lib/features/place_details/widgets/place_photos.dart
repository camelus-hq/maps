import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

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
    final ThemeData theme = Theme.of(context);
    if (urls.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('No photos yet', style: theme.textTheme.bodySmall),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String url in urls) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Photo from OpenStreetMap',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Photo unavailable',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
