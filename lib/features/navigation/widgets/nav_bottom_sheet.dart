import 'dart:async';

import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/map_style.dart';
import '../../../domain/entities/route.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/location.dart';
import '../../../state/map_layers.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../../common/map_sheet.dart';
import '../../directions/widgets/maneuver_glyph.dart';

/// The navigation bottom sheet: a draggable card whose header is the ETA row
/// and whose body carries the trip options (search along route, directions,
/// traffic, satellite).
///
/// It uses [MapSheet] so it reports its geometry to the shared sheet anchor —
/// the pinned attribution attaches to its top edge like on the other sheets.
class NavBottomSheet extends ConsumerWidget {
  const NavBottomSheet({
    super.key,
    required this.nav,
    required this.onExit,
    required this.onToggleOverview,
    required this.tracking,
  });

  final NavState nav;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;
  final bool tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return MapSheet(
      initialChildSize: 0.16,
      minChildSize: 0.14,
      maxChildSize: 0.62,
      snap: true,
      snapSizes: const <double>[0.16, 0.62],
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(bottom: bottomInset),
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              NavEtaHeader(
                nav: nav,
                imperial: imperial,
                tracking: tracking,
                onExit: onExit,
                onToggleOverview: onToggleOverview,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search along route'),
                onTap: () => context.push('/search'),
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('Directions'),
                onTap: () => _showDirections(context, nav),
              ),
              const _TrafficToggle(),
              const _SatelliteToggle(),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  void _showDirections(BuildContext context, NavState nav) {
    final Route? route = nav.route;
    if (route == null) {
      return;
    }
    final List<Maneuver> maneuvers = <Maneuver>[
      for (final Leg leg in route.legs) ...leg.maneuvers,
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final Maneuver maneuver in maneuvers)
              ListTile(
                leading: ManeuverGlyph(type: maneuver.type),
                title: Text(maneuver.instruction),
                trailing: maneuver.distanceMeters > 0
                    ? Text(formatDistance(maneuver.distanceMeters))
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// The ETA header of the navigation sheet (also the collapsed sheet state).
class NavEtaHeader extends ConsumerWidget {
  const NavEtaHeader({
    super.key,
    required this.nav,
    required this.imperial,
    required this.tracking,
    required this.onExit,
    required this.onToggleOverview,
  });

  final NavState nav;
  final bool imperial;
  final bool tracking;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool arrived = nav.status == NavStatus.arrived;
    final String? notice = nav.notice;
    final LocationState location = ref.watch(locationTrackerProvider);
    final bool gpsLost = location.lost && !arrived;
    final double remainingDistance = (nav.totalMeters - nav.traveledMeters)
        .clamp(0, double.infinity);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(arrived ? Icons.check : Icons.close),
            tooltip: arrived ? 'Done' : 'Exit',
            onPressed: onExit,
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: arrived
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Trip complete',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        formatDistance(nav.totalMeters, imperial: imperial),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : notice != null
                ? Text(notice, style: TextStyle(color: scheme.error))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            formatDuration(nav.remaining),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.schedule, size: 18, color: scheme.primary),
                        ],
                      ),
                      Text(
                        '${formatDistance(remainingDistance, imperial: imperial)}'
                        ' • Arrives ${_arrivalLabel(context, nav.remaining)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (gpsLost) ...<Widget>[
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.gps_off,
                              size: 14,
                              color: Color(0xFFDD8500),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Location unavailable',
                              style: TextStyle(
                                color: const Color(0xFFDD8500),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          if (!arrived)
            IconButton(
              icon: Icon(tracking ? Icons.map_outlined : Icons.navigation),
              tooltip: tracking ? 'Route overview' : 'Re-center',
              onPressed: onToggleOverview,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHighest,
                shape: const CircleBorder(),
              ),
            ),
        ],
      ),
    );
  }

  static String _arrivalLabel(BuildContext context, Duration duration) {
    final TimeOfDay arrival = TimeOfDay.fromDateTime(
      DateTime.now().add(duration),
    );
    return MaterialLocalizations.of(context).formatTimeOfDay(
      arrival,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

class _TrafficToggle extends ConsumerWidget {
  const _TrafficToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool on = ref.watch(trafficProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.traffic),
      title: const Text('Show traffic on map'),
      value: on,
      onChanged: (bool value) => unawaited(
        ref.read(commandRegistryProvider).dispatch(
          'map.traffic',
          <String, Object?>{'on': value},
        ),
      ),
    );
  }
}

class _SatelliteToggle extends ConsumerWidget {
  const _SatelliteToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BaseMapStyle style = ref.watch(mapStyleProvider);
    final bool on = style == BaseMapStyle.satellite;
    return SwitchListTile(
      secondary: const Icon(Icons.satellite_alt),
      title: const Text('Show satellite map'),
      value: on,
      onChanged: (bool value) => unawaited(
        ref.read(commandRegistryProvider).dispatch(
          'map.style.set',
          <String, Object?>{
            'style': value
                ? BaseMapStyle.satellite.name
                : BaseMapStyle.standard.name,
          },
        ),
      ),
    );
  }
}
