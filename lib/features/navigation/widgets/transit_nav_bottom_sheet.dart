import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import 'nav_sheet.dart';

/// The public-transport navigation sheet.
///
/// Transit guidance is arrival-led, so the sheet leads with the arrival time
/// and time left (a small "departure board" feel) rather than a speed board.
class TransitNavBottomSheet extends ConsumerWidget {
  const TransitNavBottomSheet({
    super.key,
    required this.nav,
    required this.tracking,
    required this.onExit,
    required this.onToggleOverview,
  });

  final NavState nav;
  final bool tracking;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final double remaining = (nav.totalMeters - nav.traveledMeters).clamp(
      0,
      double.infinity,
    );
    final (String, String) timeText = splitUnit(formatDuration(nav.remaining));
    final (String, String) remainingText = splitUnit(
      formatDistance(remaining, imperial: imperial),
    );
    return NavSheet(
      nav: nav,
      tracking: tracking,
      onExit: onExit,
      onToggleOverview: onToggleOverview,
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.62,
      snapSizes: const <double>[0.12, 0.22, 0.62],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            NavStatsRow(
              stats: <NavStat>[
                NavStat(arrivalLabel(context, nav.remaining), '', 'Arrives'),
                NavStat(timeText.$1, timeText.$2, 'Time left'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  Icons.directions_transit,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Public transport • ${remainingText.$1} ${remainingText.$2} '
                    'to go',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
