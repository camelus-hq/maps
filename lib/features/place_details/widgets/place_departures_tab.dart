import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/transit_stop_board.dart';
import '../../common/error_text.dart';
import '../../directions/widgets/transit/transit_common.dart';
import '../../directions/widgets/transit/transit_departure_row.dart';
import '../../directions/widgets/transit/transit_line_chip.dart';

/// The line chips for the stop the station sheet is open on: every local /
/// regional bus, tram, subway, train and ferry line that serves it, in the
/// operator's own colour.
///
/// Long-distance rail (high-speed / intercity / night) is left out — at a main
/// station it lists every train number and buries the local network — unless the
/// stop is served *only* by long-distance trains. Shown in the sheet summary as
/// soon as the stop's lines have loaded, so a tapped station advertises what
/// runs there (like the other transit screens).
class PlaceStopLines extends ConsumerWidget {
  const PlaceStopLines({super.key});

  /// Bound on the chips shown, so a mega-interchange cannot grow the summary
  /// without limit (the rest are summarised as "+N").
  static const int _maxChips = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransitStopBoardState state = ref.watch(transitStopBoardProvider);
    final List<TransitStopRoute> routes = localStopRoutes(state.routes);
    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<TransitStopRoute> shown = routes.length <= _maxChips
        ? routes
        : routes.sublist(0, _maxChips);
    final int hidden = routes.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final TransitStopRoute route in shown)
            TransitLineChip(
              label: route.lineLabel,
              color: route.displayColor,
              textColor: route.routeTextColor,
            ),
          if (hidden > 0)
            Text(
              '+$hidden',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The Departures tab of the station sheet: the next departures with a **load
/// earlier** control above the list and a **load later** control below it.
/// Tapping a departure opens that train's detail (its whole stop list) and shows
/// only that line on the map.
class PlaceDeparturesTab extends ConsumerWidget {
  const PlaceDeparturesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransitStopBoardState state = ref.watch(transitStopBoardProvider);

    if (state.hasTripDetail) {
      return const _TripDetail();
    }

    if (state.isLoading && state.departures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == StopBoardStatus.error && state.departures.isEmpty) {
      return _ErrorState(error: state.error);
    }
    if (state.departures.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No departures found for this stop',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LoadControl(
          label: 'Earlier departures',
          icon: Icons.keyboard_arrow_up,
          loading: state.loadingEarlier,
          visible: state.hasEarlier,
          command: 'transit.stop.earlier',
        ),
        for (final TransitStopDeparture departure in state.departures)
          TransitDepartureRow(
            departure: departure,
            onTap: departure.tripId?.trim().isEmpty ?? true
                ? null
                : () => ref
                      .read(transitStopBoardProvider.notifier)
                      .openTrip(departure),
          ),
        _LoadControl(
          label: 'Later departures',
          icon: Icons.keyboard_arrow_down,
          loading: state.loadingLater,
          visible: state.hasLater,
          command: 'transit.stop.later',
        ),
      ],
    );
  }
}

/// A full-width "load earlier/later departures" control with a spinner while it
/// loads.
class _LoadControl extends ConsumerWidget {
  const _LoadControl({
    required this.label,
    required this.icon,
    required this.loading,
    required this.visible,
    required this.command,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool visible;
  final String command;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible && !loading) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: TextButton.icon(
        onPressed: loading
            ? null
            : () => ref
                  .read(commandRegistryProvider)
                  .dispatch(command, const <String, Object?>{}),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// The detail of one train (opened by tapping a departure): the line, where it
/// is headed, when it leaves, and every stop along its route with its time.
class _TripDetail extends ConsumerWidget {
  const _TripDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TransitStopBoardState state = ref.watch(transitStopBoardProvider);
    final TransitStopDeparture? departure = state.selectedDeparture;
    final TransitStopLine? line = state.tripDetail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                ref.read(transitStopBoardProvider.notifier).closeTrip(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to departures'),
          ),
        ),
        if (line == null && state.tripLoading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (line == null)
          _TripError(state: state, departure: departure)
        else ...<Widget>[
          _TripHeader(departure: departure, line: line),
          const Divider(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              '${line.stops.length} stops',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (int i = 0; i < line.stops.length; i++)
            _TripStopRow(
              stop: line.stops[i],
              color: line.route.displayColor,
              first: i == 0,
              last: i == line.stops.length - 1,
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.departure, required this.line});

  final TransitStopDeparture? departure;
  final TransitStopLine line;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TransitStopDeparture? dep = departure;
    final String destination =
        dep?.headsign ?? line.route.routeLongName ?? line.stops.last.name;
    final DateTime? when = dep?.displayDeparture;
    final String? track = dep?.displayTrack;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TransitLineChip(
                label: line.route.lineLabel,
                color: line.route.displayColor,
                textColor: line.route.routeTextColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'to $destination',
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            <String>[
              line.route.mode.label,
              if (line.route.agencyName != null) line.route.agencyName!,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (dep != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      transitModeIcon(dep.mode),
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      when == null
                          ? '—'
                          : <String>[
                              transitClock(context, when.toLocal()),
                              ?relativeTimeLabel(
                                when.toLocal(),
                                now: DateTime.now(),
                              ),
                            ].join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                Text(
                  transitDepartureStatus(dep),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dep.cancelled ? scheme.error : scheme.outline,
                  ),
                ),
                if (dep.realTime && !dep.cancelled) const TransitLiveBadge(),
                if (track != null) TransitPlatformChip(track: track),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One stop on the train's route: its time, name and platform, on a small rail
/// in the line's colour.
class _TripStopRow extends StatelessWidget {
  const _TripStopRow({
    required this.stop,
    required this.color,
    required this.first,
    required this.last,
  });

  final TransitStop stop;
  final int color;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? time = stop.displayTime?.toLocal();
    final String? track = stop.displayTrack;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 58,
            child: Text(
              time == null ? '—' : transitClock(context, time),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          Column(
            children: <Widget>[
              Container(
                width: first || last ? 12 : 8,
                height: first || last ? 12 : 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: first || last ? Color(color) : scheme.surface,
                  border: Border.all(color: Color(color), width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stop.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: first || last ? FontWeight.w600 : null,
                  ),
                ),
                if (track != null)
                  Text(
                    'Platform $track',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripError extends ConsumerWidget {
  const _TripError({required this.state, required this.departure});

  final TransitStopBoardState state;
  final TransitStopDeparture? departure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({IconData icon, String text}) presentation = errorPresentation(
      state.tripError,
      fallback: 'Could not load the train',
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(presentation.icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(presentation.text, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              final TransitStopDeparture? dep = departure;
              if (dep != null) {
                ref.read(transitStopBoardProvider.notifier).openTrip(dep);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({this.error});

  final AppException? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({IconData icon, String text}) presentation = errorPresentation(
      error,
      fallback: 'Could not load departures',
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(presentation.icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(presentation.text, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(transitStopBoardProvider.notifier).retry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
