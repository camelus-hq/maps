import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../design/play.dart';

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
    final PlayColors colors = PlayColors.of(context);
    final List<String> keys = tags.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                PhosphorIconsRegular.bracketsCurly,
                size: 20,
                color: colors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'OpenStreetMap tags (${keys.length})',
                  style: PlayType.body.copyWith(color: colors.ink),
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
                    style: PlayType.caption.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    tags[key]!,
                    style: PlayType.body.copyWith(color: colors.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
