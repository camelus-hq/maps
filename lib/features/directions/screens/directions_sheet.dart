import 'dart:async';

import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/transit.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/route.dart';
import '../../../state/settings.dart';
import '../../common/error_text.dart';
import '../../common/map_sheet.dart';
import '../widgets/cycle_options.dart';
import '../widgets/maneuver_glyph.dart';
import '../widgets/transit_itineraries.dart';

/// Draggable route-preview sheet: travel modes, alternatives, ETA and steps,
/// with the start action row pinned at the bottom.
///
/// The start/stop/destination fields live on the floating
/// `DirectionsEndpointCard` that overhangs the top of the map, not here.
class DirectionsSheet extends ConsumerWidget {
  const DirectionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RouteState state = ref.watch(routeControllerProvider);
    // Step 2 of the transit flow: the journey detail replaces the list.
    final TransitItinerary? detail = state.isTransit && state.transitDetailOpen
        ? state.selectedItinerary
        : null;
    if (detail != null) {
      // Snap points: a small "peek" (the badge header and the Start/duration row
      // only), half, and near-full. The peek is a fixed content height — the
      // handle, badge header, divider and footer (plus the system inset) — as a
      // fraction of the sheet viewport.
      final double viewport = MediaQuery.sizeOf(context).height;
      final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      final double peek = ((136 + bottomInset) / viewport).clamp(0.1, 0.45);
      return MapSheet(
        initialChildSize: 0.5,
        minChildSize: peek,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: <double>[peek, 0.5, 0.92],
        builder: (BuildContext context, ScrollController scrollController) {
          return Material(
            color: scheme.surface,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.sheetRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: TransitJourneyDetail(
              itinerary: detail,
              scrollController: scrollController,
            ),
          );
        },
      );
    }
    return MapSheet(
      initialChildSize: 0.45,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const <double>[0.45, 0.92],
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: <Widget>[
                    _title(context, ref, state),
                    if (state.pickTarget != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Long-press the map to set the '
                          '${_pickTargetLabel(state.pickTarget!)}.',
                        ),
                      ),
                    SegmentedButton<TravelMode>(
                      segments: const <ButtonSegment<TravelMode>>[
                        ButtonSegment<TravelMode>(
                          value: TravelMode.cycle,
                          label: Text('Cycle'),
                        ),
                        ButtonSegment<TravelMode>(
                          value: TravelMode.transit,
                          label: Text('Transit'),
                        ),
                        ButtonSegment<TravelMode>(
                          value: TravelMode.walk,
                          label: Text('Walk'),
                        ),
                        ButtonSegment<TravelMode>(
                          value: TravelMode.drive,
                          label: Text('Drive'),
                        ),
                      ],
                      selected: <TravelMode>{state.mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<TravelMode> selection) => ref
                          .read(routeControllerProvider.notifier)
                          .setMode(selection.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (state.isTransit)
                      const TransitSection()
                    else
                      _body(context, ref, state),
                  ],
                ),
              ),
              if (state.selectedRoute != null && !state.isTransit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: _actions(ref),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _title(BuildContext context, WidgetRef ref, RouteState state) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            _modeLabel(state.mode),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => ref.read(routeControllerProvider.notifier).clear(),
        ),
      ],
    );
  }

  /// The pinned action row (Google Maps-style): a prominent Start button for
  /// real guidance, plus a simulate and a share affordance.
  Widget _actions(WidgetRef ref) {
    final registry = ref.read(commandRegistryProvider);
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () => unawaited(
              registry.dispatch('nav.start', const <String, Object?>{
                'live': true,
              }),
            ),
            icon: const Icon(Icons.navigation),
            label: const Text('Start'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: () => unawaited(
            registry.dispatch('nav.start', const <String, Object?>{
              'auto': true,
            }),
          ),
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Simulate guidance',
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: null,
          icon: const Icon(Icons.share_outlined),
          tooltip: 'Share',
        ),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, RouteState state) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    switch (state.status) {
      case RouteStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        );
      case RouteStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          state.error,
          fallback: 'Could not find a route',
        );
        return _ErrorState(
          icon: presentation.icon,
          message: presentation.text,
          onRetry: () =>
              unawaited(ref.read(routeControllerProvider.notifier).retry()),
        );
      case RouteStatus.idle:
        return const SizedBox.shrink();
      case RouteStatus.data:
        final Route? selected = state.selectedRoute;
        if (selected == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${formatDuration(selected.duration)} · '
              '${formatDistance(selected.distanceMeters, imperial: imperial)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Arrives ${_arrivalLabel(context, selected.duration)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (state.routes.length > 1) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (int i = 0; i < state.routes.length; i++)
                    ChoiceChip(
                      label: Text(
                        'Route ${i + 1} · '
                        '${formatDuration(state.routes[i].duration)}',
                      ),
                      selected: state.selectedIndex == i,
                      onSelected: (bool _) => ref
                          .read(routeControllerProvider.notifier)
                          .selectRoute(i),
                    ),
                ],
              ),
            ],
            // Bicycle cost options sit between the route alternatives and the
            // turn-by-turn directions.
            if (state.mode == TravelMode.cycle) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const CycleOptionsPanel(),
            ],
            const Divider(height: AppSpacing.lg),
            for (final Leg leg in selected.legs)
              for (final Maneuver maneuver in leg.maneuvers)
                ListTile(
                  dense: true,
                  leading: ManeuverGlyph(type: maneuver.type),
                  title: Text(maneuver.instruction),
                  trailing: maneuver.distanceMeters > 0
                      ? Text(
                          formatDistance(
                            maneuver.distanceMeters,
                            imperial: imperial,
                          ),
                        )
                      : null,
                ),
          ],
        );
    }
  }

  static String _modeLabel(TravelMode mode) => switch (mode) {
    TravelMode.drive => 'Drive',
    TravelMode.walk => 'Walk',
    TravelMode.cycle => 'Cycle',
    TravelMode.transit => 'Transit',
  };

  static String _pickTargetLabel(RouteEndpointTarget target) =>
      switch (target.field) {
        RouteEndpointField.origin => 'start',
        RouteEndpointField.destination => 'destination',
        RouteEndpointField.stop =>
          target.stopIndex == null ? 'new stop' : 'stop',
      };

  /// The projected arrival clock time, localised (respects 12/24-hour setting).
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
