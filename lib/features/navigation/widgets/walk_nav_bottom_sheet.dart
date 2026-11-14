import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/format.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import 'nav_sheet.dart';

/// The walking navigation sheet.
///
/// Walking needs no speed or gradient board — just the remaining distance,
/// time and arrival, laid out compactly, with the shared trip options below.
class WalkNavBottomSheet extends ConsumerWidget {
  const WalkNavBottomSheet({
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
    // The trip's full length, measured from the actual start so a reroute does
    // not shrink "Total" to just the re-planned remainder.
    final double totalDistance =
        nav.tripTraveledMeters.clamp(0, double.infinity) + remaining;
    final (String, String) remainingText = splitUnit(
      formatDistance(remaining, imperial: imperial, precise: true),
    );
    final (String, String) timeText = splitUnit(formatDuration(nav.remaining));
    final (String, String) totalText = splitUnit(
      formatDistance(totalDistance, imperial: imperial, precise: true),
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
      body: NavStatsGrid(
        stats: <NavStat>[
          NavStat(remainingText.$1, remainingText.$2, 'Distance'),
          NavStat(timeText.$1, timeText.$2, 'Time left'),
          NavStat(arrivalLabel(context, nav.remaining), '', 'Arrives'),
          NavStat(totalText.$1, totalText.$2, 'Total'),
        ],
      ),
    );
  }
}
