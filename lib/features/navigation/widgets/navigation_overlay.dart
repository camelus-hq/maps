import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/route.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../../directions/widgets/maneuver_glyph.dart';

/// Active-guidance overlay: top maneuver banner + bottom ETA card.
class NavigationOverlay extends ConsumerWidget {
  const NavigationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NavState nav = ref.watch(navigationControllerProvider);
    if (nav.status == NavStatus.idle) {
      return const SizedBox.shrink();
    }
    final bool imperial = ref.watch(imperialUnitsProvider);
    return Positioned.fill(
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _Banner(nav: nav, imperial: imperial),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _BottomCard(nav: nav, imperial: imperial),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.nav, required this.imperial});

  final NavState nav;
  final bool imperial;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Maneuver? maneuver = nav.nextManeuver;
    final bool arrived = nav.status == NavStatus.arrived;
    final bool rerouting = nav.status == NavStatus.rerouting;
    return Material(
      color: scheme.primaryContainer,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            ManeuverGlyph(
              type: arrived
                  ? ManeuverType.arrive
                  : (maneuver?.type ?? ManeuverType.straight),
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    arrived
                        ? 'You have arrived'
                        : rerouting
                        ? 'Rerouting…'
                        : formatDistance(
                            nav.distanceToNextManeuver,
                            imperial: imperial,
                          ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!arrived && maneuver != null)
                    Text(
                      maneuver.instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCard extends ConsumerWidget {
  const _BottomCard({required this.nav, required this.imperial});

  final NavState nav;
  final bool imperial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool arrived = nav.status == NavStatus.arrived;
    // Following = the camera tracks the puck. A user pan (or the overview)
    // stops that, and the button becomes a re-center control.
    final bool tracking = nav.cameraFollows && !nav.overview;
    return Material(
      color: scheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              arrived ? Icons.check_circle : Icons.navigation,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: arrived
                  ? const Text('Trip complete')
                  : nav.notice != null
                  ? Text(
                      nav.notice!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${formatDuration(nav.remaining)} · '
                          '${formatDistance(nav.totalMeters - nav.traveledMeters, imperial: imperial)} left',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Arrives ${_arrivalLabel(context, nav.remaining)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
            IconButton(
              icon: Icon(tracking ? Icons.map_outlined : Icons.navigation),
              tooltip: tracking ? 'Route overview' : 'Re-center',
              onPressed: () {
                final NavigationController controller = ref.read(
                  navigationControllerProvider.notifier,
                );
                if (tracking) {
                  controller.toggleOverview();
                } else {
                  controller.resumeTracking();
                }
              },
            ),
            TextButton(
              onPressed: () =>
                  ref.read(navigationControllerProvider.notifier).stop(),
              child: Text(arrived ? 'Done' : 'Exit'),
            ),
          ],
        ),
      ),
    );
  }
}

String _arrivalLabel(BuildContext context, Duration duration) {
  final TimeOfDay arrival = TimeOfDay.fromDateTime(
    DateTime.now().add(duration),
  );
  return MaterialLocalizations.of(context).formatTimeOfDay(
    arrival,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
