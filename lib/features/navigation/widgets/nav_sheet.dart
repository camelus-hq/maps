import 'dart:async';

import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/map_style.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/location.dart';
import '../../../state/map_layers.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../../common/map_sheet.dart';
import '../../directions/widgets/maneuver_glyph.dart';

/// The shared shell of every navigation bottom sheet.
///
/// It owns the geometry ([MapSheet]), the grab handle, the ETA header and the
/// trip options, and leaves the middle to a mode-specific [body] — so each
/// travel mode gets its own sheet (car / cycling / walking / transit) while the
/// chrome and gestures stay identical. The sheet reports its geometry to
/// [sheetAnchorProvider] so the pinned attribution attaches to its top edge.
class NavSheet extends ConsumerWidget {
  const NavSheet({
    super.key,
    required this.nav,
    required this.tracking,
    required this.onExit,
    required this.onToggleOverview,
    this.body,
    this.initialChildSize = 0.16,
    this.minChildSize = 0.14,
    this.maxChildSize = 0.62,
    this.snapSizes = const <double>[0.16, 0.62],
    this.topPadding = 0,
  });

  final NavState nav;
  final bool tracking;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;

  /// The mode-specific content shown between the ETA header and the trip
  /// options (a stats board, a gradient profile, …).
  final Widget? body;

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double> snapSizes;

  /// Extra space above the body so a taller default snap does not peek the
  /// trip options below it.
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final Widget? body = this.body;
    return MapSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: true,
      snapSizes: snapSizes,
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
              const SheetDragHandle(),
              NavEtaHeader(
                nav: nav,
                imperial: imperial,
                tracking: tracking,
                onExit: onExit,
                onToggleOverview: onToggleOverview,
              ),
              if (body != null) ...<Widget>[
                const Divider(height: 1),
                body,
                if (topPadding > 0) SizedBox(height: topPadding),
              ],
              const Divider(height: 1),
              NavTripOptions(nav: nav),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

/// The rounded grabber at the top of a sheet.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
      ],
    );
  }
}

/// The ETA header of a navigation sheet (also the collapsed sheet state).
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
    // Walking and cycling readouts change every few metres, so keep the extra
    // decimal there; driving keeps the shorter 100 m-step form.
    final bool precise =
        nav.mode == TravelMode.walk || nav.mode == TravelMode.cycle;
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
                        formatDistance(
                          nav.totalMeters,
                          imperial: imperial,
                          precise: precise,
                        ),
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
                        '${formatDistance(remainingDistance, imperial: imperial, precise: precise)}'
                        ' • Arrives ${arrivalLabel(context, nav.remaining)}',
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
}

/// A clock label for "now + [duration]" (e.g. "11:25 AM").
String arrivalLabel(BuildContext context, Duration duration) {
  final TimeOfDay arrival = TimeOfDay.fromDateTime(
    DateTime.now().add(duration),
  );
  return MaterialLocalizations.of(context).formatTimeOfDay(
    arrival,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// The trip options revealed when a navigation sheet is expanded: search along
/// the route, the step-by-step list, and the map-layer toggles. Shared by every
/// mode's sheet.
class NavTripOptions extends ConsumerWidget {
  const NavTripOptions({super.key, required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Search along route'),
          onTap: () => context.push('/search'),
        ),
        ListTile(
          leading: const Icon(Icons.list),
          title: const Text('Directions'),
          onTap: () => showNavDirections(context, nav),
        ),
        const _TrafficToggle(),
        const _SatelliteToggle(),
      ],
    );
  }
}

/// Opens the step-by-step list for [nav]; each step carries a maneuver glyph.
void showNavDirections(BuildContext context, NavState nav) {
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

// --- Ride/route statistics (shared by the cycling and walking sheets) -------

/// A single stat: a value, its unit, and a caption.
class NavStat {
  const NavStat(this.value, this.unit, this.label, {this.accent});

  final String value;
  final String unit;
  final String label;

  /// An optional accent colour for the value (e.g. climbing vs descending).
  final Color? accent;
}

/// One page of stats laid out in a two-column grid.
class NavStatsGrid extends StatelessWidget {
  const NavStatsGrid({super.key, required this.stats});

  final List<NavStat> stats;

  @override
  Widget build(BuildContext context) {
    Widget cell(int index) => Expanded(
      child: index < stats.length
          ? NavStatCell(stat: stats[index])
          : const SizedBox.shrink(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Row(children: <Widget>[cell(0), cell(1)]),
          Row(children: <Widget>[cell(2), cell(3)]),
        ],
      ),
    );
  }
}

/// A single row of stats laid side by side (used by the transit sheet).
class NavStatsRow extends StatelessWidget {
  const NavStatsRow({super.key, required this.stats});

  final List<NavStat> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          for (final NavStat stat in stats)
            Expanded(child: NavStatCell(stat: stat)),
        ],
      ),
    );
  }
}

class NavStatCell extends StatelessWidget {
  const NavStatCell({super.key, required this.stat});

  final NavStat stat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text.rich(
          TextSpan(
            text: stat.value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: stat.accent,
            ),
            children: stat.unit.isEmpty
                ? null
                : <InlineSpan>[
                    TextSpan(
                      text: ' ${stat.unit}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
          ),
        ),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A horizontally paged board of [pages] with page dots under it.
///
/// The parent may pass a [controller] to switch pages programmatically (the
/// cycling sheet slides to the gradient page as a climb approaches).
class NavStatsPager extends StatefulWidget {
  const NavStatsPager({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.height = 132,
  });

  final List<Widget> pages;
  final PageController? controller;

  /// Called when the visible page settles on a new index (both automatic and
  /// rider-initiated changes).
  final ValueChanged<int>? onPageChanged;

  final double height;

  @override
  State<NavStatsPager> createState() => _NavStatsPagerState();
}

class _NavStatsPagerState extends State<NavStatsPager> {
  late final PageController _controller = widget.controller ?? PageController();
  late final bool _ownsController = widget.controller == null;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _page = _controller.initialPage;
    _controller.addListener(_onPage);
  }

  void _onPage() {
    final double? page = _controller.hasClients
        ? _controller.page
        : _controller.initialPage.toDouble();
    if (page == null) {
      return;
    }
    final int rounded = page.round();
    if (rounded != _page) {
      setState(() => _page = rounded);
      widget.onPageChanged?.call(rounded);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPage);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: widget.height,
            child: PageView(controller: _controller, children: widget.pages),
          ),
          if (widget.pages.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            NavPageDots(count: widget.pages.length, active: _page),
          ],
        ],
      ),
    );
  }
}

/// The row of dots marking a pager's current page.
class NavPageDots extends StatelessWidget {
  const NavPageDots({super.key, required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == active ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// The current road speed in km/h from the tracked fix, when known.
double? currentSpeedKmh(WidgetRef ref) {
  final double? metersPerSecond = ref
      .watch(locationTrackerProvider)
      .fix
      ?.speedMetersPerSecond;
  if (metersPerSecond == null || !metersPerSecond.isFinite) {
    return null;
  }
  return metersPerSecond * 3.6;
}

/// The trip's elapsed wall-clock time, measured from the session start so a
/// reroute never restarts the clock. Zero before the trip starts.
Duration tripElapsed(NavState nav, {DateTime? now}) {
  final DateTime? start = nav.startedAt;
  if (start == null) {
    return Duration.zero;
  }
  final Duration elapsed = (now ?? DateTime.now()).difference(start);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

/// Splits a formatted value (e.g. "850 m", "12 min") into number and unit.
(String, String) splitUnit(String formatted) {
  final int index = formatted.lastIndexOf(' ');
  if (index <= 0) {
    return (formatted, '');
  }
  return (formatted.substring(0, index), formatted.substring(index + 1));
}

/// A speed value + unit ("12", "km/h"), tolerating an unknown speed.
(String, String) formatSpeed(double? kmh, bool imperial) {
  final String unit = imperial ? 'mph' : 'km/h';
  if (kmh == null || !kmh.isFinite) {
    return ('--', unit);
  }
  final double value = imperial ? kmh * 0.621371 : kmh;
  return (value.round().toString(), unit);
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
