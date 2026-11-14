import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';

/// Developer view of every raw OpenStreetMap tag on a place, shown only when the
/// "Show all OpenStreetMap tags" setting is on.
class PlaceOsmTags extends StatelessWidget {
  const PlaceOsmTags({super.key, required this.tags});

  final Map<String, String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<String> keys = tags.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.data_object, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'OpenStreetMap tags (${keys.length})',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final String key in keys)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md + 20,
                bottom: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(tags[key]!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
