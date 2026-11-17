import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/transit_stop_board.dart';
import '../../common/error_text.dart';
import '../../common/shimmer.dart';
import '../../design/play.dart';
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
    final PlayColors colors = PlayColors.of(context);
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
              style: PlayType.caption.copyWith(color: colors.inkMuted),
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
      return const _DeparturesLoadingSkeleton();
    }
    if (state.status == StopBoardStatus.error && state.departures.isEmpty) {
      return _ErrorState(error: state.error);
    }
    if (state.departures.isEmpty) {
      final PlayColors colors = PlayColors.of(context);
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No departures found for this stop',
            style: PlayType.body.copyWith(color: colors.ink),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LoadControl(
          label: 'Earlier departures',
          icon: PhosphorIconsRegular.caretUp,
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
          icon: PhosphorIconsRegular.caretDown,
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
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: PlayPressable(
        enabled: !loading,
        onTap: loading
            ? null
            : () => ref
                  .read(commandRegistryProvider)
                  .dispatch(command, const <String, Object?>{}),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (loading)
                  const PlaySpinner(size: 16, strokeWidth: 2)
                else
                  Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: PlayType.bodyStrong.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
        ),
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
    final PlayColors colors = PlayColors.of(context);
    final TransitStopBoardState state = ref.watch(transitStopBoardProvider);
    final TransitStopDeparture? departure = state.selectedDeparture;
    final TransitStopLine? line = state.tripDetail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: PlayButton(
            label: 'Back to departures',
            icon: PlayIcons.back,
            variant: PlayButtonVariant.ghost,
            size: PlayButtonSize.sm,
            onPressed: () =>
                ref.read(transitStopBoardProvider.notifier).closeTrip(),
          ),
        ),
        if (line == null && state.tripLoading)
          const _TripLoadingSkeleton()
        else if (line == null)
          _TripError(state: state, departure: departure)
        else ...<Widget>[
          _TripHeader(departure: departure, line: line),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: PlayDivider(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              '${line.stops.length} stops',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
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
    final PlayColors colors = PlayColors.of(context);
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
                  style: PlayType.title.copyWith(color: colors.ink),
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
            style: PlayType.caption.copyWith(color: colors.inkMuted),
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
                      color: colors.primary,
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
                      style: PlayType.body.copyWith(color: colors.ink),
                    ),
                  ],
                ),
                Text(
                  transitDepartureStatus(dep),
                  style: PlayType.caption.copyWith(
                    color: dep.cancelled ? colors.coral : colors.inkFaint,
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
    final PlayColors colors = PlayColors.of(context);
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
              style: PlayType.caption.copyWith(
                color: colors.inkMuted,
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
                  color: first || last ? Color(color) : colors.surface,
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
                  style: PlayType.body.copyWith(
                    color: colors.ink,
                    fontWeight: first || last ? FontWeight.w600 : null,
                  ),
                ),
                if (track != null)
                  Text(
                    'Platform $track',
                    style: PlayType.caption.copyWith(color: colors.inkFaint),
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
    final PlayColors colors = PlayColors.of(context);
    final ({IconData icon, String text}) presentation = errorPresentation(
      state.tripError,
      fallback: 'Could not load the train',
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(presentation.icon, color: colors.inkFaint),
          const SizedBox(height: AppSpacing.sm),
          Text(
            presentation.text,
            textAlign: TextAlign.center,
            style: PlayType.body.copyWith(color: colors.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          PlayButton(
            label: 'Retry',
            icon: PlayIcons.refresh,
            variant: PlayButtonVariant.ghost,
            size: PlayButtonSize.sm,
            onPressed: () {
              final TransitStopDeparture? dep = departure;
              if (dep != null) {
                ref.read(transitStopBoardProvider.notifier).openTrip(dep);
              }
            },
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
    final PlayColors colors = PlayColors.of(context);
    final ({IconData icon, String text}) presentation = errorPresentation(
      error,
      fallback: 'Could not load departures',
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(presentation.icon, color: colors.inkFaint),
          const SizedBox(height: AppSpacing.sm),
          Text(
            presentation.text,
            textAlign: TextAlign.center,
            style: PlayType.body.copyWith(color: colors.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          PlayButton(
            label: 'Retry',
            icon: PlayIcons.refresh,
            variant: PlayButtonVariant.ghost,
            size: PlayButtonSize.sm,
            onPressed: () =>
                ref.read(transitStopBoardProvider.notifier).retry(),
          ),
        ],
      ),
    );
  }
}

/// The shimmering stand-in for the departure list while the stop board loads:
/// a line badge, a destination and a time per row.
class _DeparturesLoadingSkeleton extends StatelessWidget {
  const _DeparturesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ShimmerBox(width: 52, height: 24, radius: 6),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ShimmerBox(width: 150, height: 14),
                        SizedBox(height: AppSpacing.xs + 2),
                        ShimmerBox(width: 100, height: 12),
                      ],
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

/// The shimmering stand-in for a train's stop list while the trip detail loads.
class _TripLoadingSkeleton extends StatelessWidget {
  const _TripLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ShimmerBox(width: 180, height: 20),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              child: Row(
                children: <Widget>[
                  ShimmerBox(width: 46, height: 12),
                  SizedBox(width: AppSpacing.sm),
                  ShimmerBox(height: 10, circle: true),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: ShimmerBox(height: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
