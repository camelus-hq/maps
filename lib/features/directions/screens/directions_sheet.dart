import 'dart:async';

import 'package:flutter/widgets.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

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
import '../../common/shimmer.dart';
import '../../design/play.dart';
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
          return PlaySheet(
            radius: PlayRadii.lg,
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
        return PlaySheet(
          radius: PlayRadii.lg,
          child: Column(
            children: <Widget>[
              const PlaySheetHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
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
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final (TravelMode mode, String label)
                            in const <(TravelMode, String)>[
                              (TravelMode.cycle, 'Cycle'),
                              (TravelMode.transit, 'Transit'),
                              (TravelMode.walk, 'Walk'),
                              (TravelMode.drive, 'Drive'),
                            ])
                          PlayChip(
                            label: label,
                            selected: state.mode == mode,
                            onTap: () => ref
                                .read(routeControllerProvider.notifier)
                                .setMode(mode),
                          ),
                      ],
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
    final PlayColors colors = PlayColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            _modeLabel(state.mode),
            style: PlayType.title.copyWith(color: colors.ink),
          ),
        ),
        PlayIconButton(
          icon: PlayIcons.close,
          variant: PlayIconButtonVariant.plain,
          size: 44,
          semanticLabel: 'Close',
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
          child: PlayButton(
            label: 'Start',
            icon: PlayIcons.navigation,
            onPressed: () => unawaited(
              registry.dispatch('nav.start', const <String, Object?>{
                'live': true,
              }),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PlayIconButton(
          icon: PhosphorIconsRegular.play,
          tone: PlayTone.soft,
          semanticLabel: 'Simulate guidance',
          onPressed: () => unawaited(
            registry.dispatch('nav.start', const <String, Object?>{
              'auto': true,
            }),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const PlayIconButton(
          icon: PlayIcons.share,
          tone: PlayTone.soft,
          semanticLabel: 'Share',
        ),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, RouteState state) {
    final PlayColors colors = PlayColors.of(context);
    final bool imperial = ref.watch(imperialUnitsProvider);
    switch (state.status) {
      case RouteStatus.loading:
        return const _RouteLoadingSkeleton();
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
              style: PlayType.subtitle.copyWith(color: colors.ink),
            ),
            Text(
              'Arrives ${_arrivalLabel(context, selected.duration)}',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
            if (state.routes.length > 1) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (int i = 0; i < state.routes.length; i++)
                    PlayChip(
                      label:
                          'Route ${i + 1} · '
                          '${formatDuration(state.routes[i].duration)}',
                      selected: state.selectedIndex == i,
                      onTap: () => ref
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: PlayDivider(),
            ),
            for (final Leg leg in selected.legs)
              for (final Maneuver maneuver in leg.maneuvers)
                PlayRow(
                  label: maneuver.instruction,
                  leading: ManeuverGlyph(type: maneuver.type),
                  showChevron: false,
                  trailing: maneuver.distanceMeters > 0
                      ? Text(
                          formatDistance(
                            maneuver.distanceMeters,
                            imperial: imperial,
                          ),
                          style: PlayType.caption.copyWith(
                            color: colors.inkMuted,
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
    return _clockLabel(
      DateTime.now().add(duration),
      use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  /// Formatted as `HH:mm` (24-hour) or `h:mm AM/PM` — the play kit carries no
  /// Material localisation, so the clock is formatted directly.
  static String _clockLabel(DateTime time, {required bool use24HourFormat}) {
    final String minute = time.minute.toString().padLeft(2, '0');
    if (use24HourFormat) {
      return '${time.hour.toString().padLeft(2, '0')}:$minute';
    }
    final int hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.icon = PlayIcons.error,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(icon, color: colors.inkFaint),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          PlayButton(
            label: 'Retry',
            icon: PlayIcons.refresh,
            variant: PlayButtonVariant.ghost,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// The shimmering stand-in shown while a route is being planned: the
/// duration / distance headline and a handful of turn-by-turn rows.
class _RouteLoadingSkeleton extends StatelessWidget {
  const _RouteLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShimmerBox(width: 170, height: 20),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(width: 120, height: 12),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(width: 90, height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: PlayDivider(),
          ),
          for (int i = 0; i < 5; i++) ...<Widget>[
            Row(
              children: <Widget>[
                const ShimmerBox(height: 22, circle: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: i.isEven ? 1.0 : 0.7,
                    child: const ShimmerBox(height: 14),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const ShimmerBox(width: 36, height: 12),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
